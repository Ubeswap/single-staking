// SPDX-License-Identifier: MIT
// solhint-disable not-rely-on-time

pragma solidity ^0.8.3;

import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "./interfaces/IRomulusDelegate.sol";
import "./interfaces/IStakingRewards.sol";
import "./RewardsDistributionRecipient.sol";
import "./interfaces/IPoolManager.sol";
import "./Voter.sol";
import "./interfaces/IPoolManager.sol";

// Base: https://github.com/Ubeswap/ubeswap-farming/blob/master/contracts/synthetix/contracts/StakingRewards.sol
contract VotableStakingRewards is
  IStakingRewards,
  RewardsDistributionRecipient,
  ReentrancyGuard
{
  using SafeMath for uint256;
  using SafeERC20 for IERC20;

  /* ========== STATE VARIABLES ========== */

  IERC20 public rewardsToken;
  IERC20 public stakingToken;
  uint256 public periodFinish = 0;
  uint256 public rewardRate = 0;
  uint256 public rewardsDuration = 7 days;
  uint256 public lastUpdateTime;
  uint256 public rewardPerTokenStored;

  IRomulusDelegate public immutable romulusDelegate;
  IPoolManager public poolManager;
  mapping(address => uint256) public userRewardPerTokenPaid;
  mapping(address => uint256) public rewards;

  uint256 private _totalSupply;
  mapping(address => uint256) private _balances;
  mapping(address => Voter) public voters;

  /* ========== CONSTRUCTOR ========== */

  constructor(
    address _owner,
    address _rewardsDistribution,
    address _rewardsToken,
    address _stakingToken,
    IRomulusDelegate _romulusDelegate
  ) Owned(_owner) {
    rewardsToken = IERC20(_rewardsToken);
    stakingToken = IERC20(_stakingToken);
    rewardsDistribution = _rewardsDistribution;
    romulusDelegate = _romulusDelegate;
  }

  /* ========== VIEWS ========== */

  ///@notice Returns the total amount of tokens staked into the contract
  function totalSupply() external view override returns (uint256) {
    return _totalSupply;
  }

  /** 
   * @notice Returns the total amount of tokens a user has staked
   * @param account The address of the account to check balance of
   */ 
  function balanceOf(address account) external view override returns (uint256) {
    return _balances[account];
  }

  /// @notice Returns the remaining time that the reward rate is available
  function lastTimeRewardApplicable() public view override returns (uint256) {
    return Math.min(block.timestamp, periodFinish);
  }

  /// @notice Returns projected amount of rewards to be gained over time per token
  function rewardPerToken() public view override returns (uint256) {
    if (_totalSupply == 0) {
      return rewardPerTokenStored;
    }
    return
      rewardPerTokenStored.add(
        lastTimeRewardApplicable()
          .sub(lastUpdateTime)
          .mul(rewardRate)
          .mul(1e18)
          .div(_totalSupply)
      );
  }

  /// @notice Returns the total amount of rewards 'msg.sender' has yielded in rewards
  function earned(address account) public view override returns (uint256) {
    return
      _balances[account]
        .mul(rewardPerToken().sub(userRewardPerTokenPaid[account]))
        .div(1e18)
        .add(rewards[account]);
  }

  /// @notice Returns amount of rewards available throughout its duration
  function getRewardForDuration() external view override returns (uint256) {
    return rewardRate.mul(rewardsDuration);
  }

  /* ========== MUTATIVE FUNCTIONS ========== */

  /**
   * @notice Stakes tokens into contract from 'msg.sender'
   * @param amount The amount of tokens to stake  
   */ 
  function stake(uint256 amount)
    external
    nonReentrant
    updateReward(msg.sender)
  {
    require(amount > 0, "Cannot stake 0");
    _totalSupply = _totalSupply.add(amount); //do this at the end? to make sure everything proceeds correctly
    _balances[msg.sender] = _balances[msg.sender].add(amount);

    if (address(voters[msg.sender]) == address(0)) {
      voters[msg.sender] = new Voter(
        IVotingDelegates(address(stakingToken)),
        romulusDelegate
      );
    } 

    Voter v = voters[msg.sender];
    require(
      stakingToken.approve(address(v), amount),
      "Approve to voter failed"
    );

    stakingToken.safeTransferFrom( msg.sender, address(v), amount);
    emit Staked(msg.sender, amount);
  }

  /**
   * @notice Withdraws staked tokens to 'msg.sender'
   * @param amount The amount to withdraw
   */ 
  function withdraw(uint256 amount)
    public
    override
    nonReentrant
    updateReward(msg.sender)
    hasVoter()
  {
    require(amount > 0, "Cannot withdraw 0");
    require(this.unstake(amount) == true, "Unstake failed");
    _totalSupply = _totalSupply.sub(amount);
    _balances[msg.sender] = _balances[msg.sender].sub(amount);
    Voter v = voters[msg.sender];
    v.removeVotes(amount);
    //BRING THIS UP TO BRIAN (remove middle man here?) instead of transferring from voter to staking token, transfer from voter to msg.sender?
    stakingToken.safeTransfer(msg.sender, amount);
    emit Withdrawn(msg.sender, amount);
  }

  /// @notice Claims rewards of 'msg.sender'
  function getReward() public override nonReentrant updateReward(msg.sender) {
    uint256 reward = rewards[msg.sender];
    if (reward > 0) {
      rewards[msg.sender] = 0;
      rewardsToken.safeTransfer(msg.sender, reward);
      emit RewardPaid(msg.sender, reward);
    }
  }

  /// @notice Withdraws all staked tokens and claims any pending rewards
  function exit() external override {
    withdraw(_balances[msg.sender]);
    getReward();
  }

  /* ========== RESTRICTED FUNCTIONS ========== */

  function notifyRewardAmount(uint256 reward)
    external
    override
    onlyRewardsDistribution
    updateReward(address(0))
  {
    if (block.timestamp >= periodFinish) {
      rewardRate = reward.div(rewardsDuration);
    } else {
      uint256 remaining = periodFinish.sub(block.timestamp);
      uint256 leftover = remaining.mul(rewardRate);
      rewardRate = reward.add(leftover).div(rewardsDuration);
    }

    // Ensure the provided reward amount is not more than the balance in the contract.
    // This keeps the reward rate in the right range, preventing overflows due to
    // very high values of rewardRate in the earned and rewardsPerToken functions;
    // Reward + leftover must be less than 2^256 / 10^18 to avoid overflow.
    uint256 balance = rewardsToken.balanceOf(address(this));
    require(
      rewardRate <= balance.div(rewardsDuration),
      "Provided reward too high"
    );

    lastUpdateTime = block.timestamp;
    periodFinish = block.timestamp.add(rewardsDuration);
    emit RewardAdded(reward);
  }

  // Added to support recovering LP Rewards from other systems such as BAL to be distributed to holders
  function recoverERC20(address tokenAddress, uint256 tokenAmount)
    external
    onlyOwner
  {
    require(
      tokenAddress != address(stakingToken),
      "Cannot withdraw the staking token"
    );
    IERC20(tokenAddress).safeTransfer(owner, tokenAmount);
    emit Recovered(tokenAddress, tokenAmount);
  }

  function setRewardsDuration(uint256 _rewardsDuration) external onlyOwner {
    require(
      block.timestamp > periodFinish,
      "Previous rewards period must be complete before changing the duration for the new period"
    );
    rewardsDuration = _rewardsDuration;
    emit RewardsDurationUpdated(rewardsDuration);
  }

  /* ========== VOTER FUNCTIONS ========== */
    
    /*development:
      1. set up locking feature
      2. make sure voter can only allocate up to the amount of ube they have
      3. calculate the weights at the end of the locking period
    */


uint256 lockDuration = 6 days;
uint256 lockTime;
mapping(address => uint256) userLocked;
mapping(address => mapping(uint256 => uint256)) userWeights;
mapping(uint256 => uint256) poolWeights;

function getPoolWeight(uint256 poolId) public view returns(uint256) {
  return poolWeights[poolId];
}

function allocate_pool_weight(uint256 poolId, uint256 amount) external{
  require(this.isLocked());
  require(amount > 0, "Cannot allocate 0");
  Voter v = voters[msg.sender];
  require(rewardsToken.balanceOf(address(v)) - userLocked[address(v)] >= amount, "Cannot allocate more than you have");
    
  userLocked[address(v)] += amount;
  userWeights[address(v)][poolId] += amount;
  poolWeights[poolId] += amount;
}

function remove_pool_weight(uint256 poolId, uint256 amount) external {
  require(!this.isLocked(), "Cannot remove weight, period is locked");

  Voter v = voters[msg.sender];
  require(amount > 0, "Cannot remove 0");
  require(userWeights[address(v)][poolId] >= amount, "Cannot remove more than you have");

  userLocked[address(v)] -= amount;
  userWeights[address(v)][poolId] -= amount; // Dont forget to check for underflow
  poolWeights[poolId] -= amount;
}

function unstake(uint256 amount) external view returns(bool){
  require(amount > 0, "Cannot remove 0");
  Voter v = voters[msg.sender];
  uint256 withdrawable = this.balanceOf(address(v));
  withdrawable -= userLocked[address(v)];
  require(amount <= withdrawable, "Withdrawing too much");
  return true;
}

function lock() external{
  require(!this.isLocked(), "Already locked");

  uint256 poolsCount = poolManager.poolsCount();
  for (uint256 i = 0; i < poolsCount; i++) {
    poolManager.setWeight(poolManager.poolsByIndex(i), poolWeights[i]);
  }

  lockTime = block.timestamp;
}


function isLocked() external view returns (bool) {
  uint256 timeElapsed = block.timestamp - lockTime;
  return timeElapsed < lockDuration;
}

function setLockDuration(uint256 _lockDuration) external onlyOwner {
  lockDuration =  _lockDuration;
}

  /// @notice Creates a proposal from the voter of 'msg.sender'
  function propose(
    address[] memory targets,
    uint256[] memory values,
    string[] memory signatures,
    bytes[] memory calldatas,
    string memory description
    ) external hasVoter() {
    voters[msg.sender].propose(        
      targets,
      values,
      signatures,
      calldatas,
      description
    );
  }

  /** 
   * @notice Casts vote for/against/abstain proposal using voter of 'msg.sender'
   * @param proposalId id of the proposal to vote for/against/abstain
   * @param support - If 0, vote against - If 1, vote for - If 2, abstain
   */
  function castVote(uint256 proposalId, uint8 support) external hasVoter() {
    voters[msg.sender].castVote(proposalId, support);
  }

  /**
   * @notice Delegate votes from voter of `msg.sender` to `delegatee`
   * @param delegatee The address to delegate votes to
   */
  function delegate(address delegatee) external hasVoter() {
    voters[msg.sender].delegate(delegatee);
  }

  /* ========== MODIFIERS ========== */

  modifier updateReward(address account) {
    rewardPerTokenStored = rewardPerToken();
    lastUpdateTime = lastTimeRewardApplicable();
    if (account != address(0)) {
      rewards[account] = earned(account);
      userRewardPerTokenPaid[account] = rewardPerTokenStored;
    }
    _;
  }

  modifier hasVoter() {
    require(address(voters[msg.sender]) != address(0));
    _;
  }

  /* ========== EVENTS ========== */

  event RewardAdded(uint256 reward);
  event Staked(address indexed user, uint256 amount);
  event Withdrawn(address indexed user, uint256 amount);
  event RewardPaid(address indexed user, uint256 reward);
  event RewardsDurationUpdated(uint256 newDuration);
  event Recovered(address token, uint256 amount);
  event DelegateIdxChanged(uint8 previousDelegateIdx, uint8 nextDelegateIdx);
}
