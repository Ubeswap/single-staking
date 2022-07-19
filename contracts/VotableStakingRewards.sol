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
import "./Voter.sol";

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
  mapping(address => uint256) public userRewardPerTokenPaid;
  mapping(address => uint256) public rewards;

  uint256 private _totalSupply;
  mapping(address => uint256) private _balances;
  mapping(address => Voter) public voters;
  uint256 public latestID = 0;

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

  function totalSupply() external view override returns (uint256) {
    return _totalSupply;
  }

  /// @notice Returns the total amount a user has staked
  function balanceOf(address account) external view override returns (uint256) {
    return _balances[account];
  }

  function lastTimeRewardApplicable() public view override returns (uint256) {
    return Math.min(block.timestamp, periodFinish);
  }

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

  function earned(address account) public view override returns (uint256) {
    return
      _balances[account]
        .mul(rewardPerToken().sub(userRewardPerTokenPaid[account]))
        .div(1e18)
        .add(rewards[account]);
  }

  function getRewardForDuration() external view override returns (uint256) {
    return rewardRate.mul(rewardsDuration);
  }

  /* ========== MUTATIVE FUNCTIONS ========== */

  /// @notice stakes user tokens into contract
  function stake(uint256 amount)
    external
    nonReentrant
    updateReward(msg.sender)
  {
    require(amount > 0, "Cannot stake 0");
    _totalSupply = _totalSupply.add(amount);
    _balances[msg.sender] = _balances[msg.sender].add(amount);
    stakingToken.safeTransferFrom(msg.sender, address(this), amount);

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

    IERC20(address(stakingToken)).safeTransferFrom( address(this), address(v), amount); //directly from user to voter
    emit Staked(msg.sender, amount);
  }

  /// @notice withdraws staked tokens
  function withdraw(uint256 amount)
    public
    override
    nonReentrant
    updateReward(msg.sender)
    checkUser(msg.sender)
  {
    require(amount > 0, "Cannot withdraw 0");
    _totalSupply = _totalSupply.sub(amount);
    _balances[msg.sender] = _balances[msg.sender].sub(amount);
    
    Voter v = voters[msg.sender];
    v.removeVotes(amount);
    stakingToken.safeTransfer(msg.sender, amount);
    emit Withdrawn(msg.sender, amount);
  }

  function getReward() public override nonReentrant updateReward(msg.sender) {
    uint256 reward = rewards[msg.sender];
    if (reward > 0) {
      rewards[msg.sender] = 0;
      rewardsToken.safeTransfer(msg.sender, reward);
      emit RewardPaid(msg.sender, reward);
    }
  }

  /// @notice withdraws all staked tokens and claims any pending rewards
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
    
  function propose(
    address[] memory targets,
    uint256[] memory values,
    string[] memory signatures,
    bytes[] memory calldatas,
    string memory description
    ) external checkUser(msg.sender) {
    voters[msg.sender].propose(        
      targets,
      values,
      signatures,
      calldatas,
      description
    );
  }

  function castVote(uint256 proposalId, uint8 support) external onlyOwner checkUser(msg.sender) {
    voters[msg.sender].castVote(proposalId, support);
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

  modifier checkUser(address user) {
    require(address(voters[user]) != address(0));
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
