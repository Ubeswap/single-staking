// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "./interfaces/IRomulusDelegate.sol";
import "./interfaces/IStakingRewards.sol";
import "./RewardsDistributionRecipient.sol";
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

  IRomulusDelegate public immutable romulusDelegate;

  IERC20 public rewardsToken;
  IERC20 public stakingToken;
  uint256 public periodFinish = 0;
  uint256 public rewardRate = 0;
  uint256 public rewardsDuration = 7 days;
  uint256 public lastUpdateTime;
  uint256 public rewardPerTokenStored;

  IPoolManager public poolManager;
  uint256 public lockDuration;
  uint256 public lockTime;
  mapping(address => uint256) public userLocked;
  mapping(address => mapping(uint256 => uint256)) public userWeights;
  mapping(uint256 => uint256) public poolWeights;

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
    IRomulusDelegate _romulusDelegate,
    IPoolManager _poolManager,
    uint256 _lockDuration
  ) Owned(_owner) {
    rewardsToken = IERC20(_rewardsToken);
    stakingToken = IERC20(_stakingToken);
    rewardsDistribution = _rewardsDistribution;
    romulusDelegate = _romulusDelegate;
    poolManager = _poolManager;
    lockDuration = _lockDuration;
  }

  /* ========== VIEWS ========== */

  function totalSupply() external view override returns (uint256) {
    return _totalSupply;
  }

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

  function stake(uint256 amount)
    external
    override
    nonReentrant
    updateReward(msg.sender)
  {
    require(amount > 0, "Cannot stake 0");
    _totalSupply = _totalSupply.add(amount);
    _balances[msg.sender] = _balances[msg.sender].add(amount);
    if (address(voters[msg.sender]) == address(0)) {
      voters[msg.sender] = new Voter(
        address(this), // controller
        msg.sender, // user
        IVotingDelegates(address(stakingToken)),
        romulusDelegate
      );
    }
    Voter v = voters[msg.sender];
    stakingToken.safeTransferFrom(msg.sender, address(v), amount);
    emit Staked(msg.sender, amount);
  }

  function withdraw(uint256 amount)
    public
    override
    nonReentrant
    updateReward(msg.sender)
  {
    require(address(voters[msg.sender]) != address(0), "Caller has no voter");
    require(amount > 0, "Cannot withdraw 0");
    uint256 withdrawable = _balances[msg.sender].sub(userLocked[msg.sender]);
    require(amount <= withdrawable, "Withdrawing more than available");
    _totalSupply = _totalSupply.sub(amount);
    _balances[msg.sender] = _balances[msg.sender].sub(amount);
    Voter v = voters[msg.sender];
    v.removeVotes(msg.sender, amount);
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

  function exit() external override {
    withdraw(_balances[msg.sender].sub(userLocked[msg.sender]));
    getReward();
  }

  function allocatePoolWeight(uint256 poolId, uint256 amount) external {
    require(
      amount.add(userLocked[msg.sender]) <= _balances[msg.sender],
      "Allocating too much"
    );

    userLocked[msg.sender] = userLocked[msg.sender].add(amount);
    userWeights[msg.sender][poolId] = userWeights[msg.sender][poolId].add(amount);
    poolWeights[poolId] = poolWeights[poolId].add(amount);
  }

  function removePoolWeight(uint256 poolId, uint256 amount) external isUnlocked {
    require(userWeights[msg.sender][poolId] >= amount, "Removing too much");

    userLocked[msg.sender] = userLocked[msg.sender].sub(amount);
    userWeights[msg.sender][poolId] = userWeights[msg.sender][poolId].sub(amount);
    poolWeights[poolId] = poolWeights[poolId].sub(amount);
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

  function setRewardsDuration(uint256 _rewardsDuration) external onlyOwner {
    require(
      block.timestamp > periodFinish,
      "Rewards period must be end before changing the rewardsDuration"
    );
    rewardsDuration = _rewardsDuration;
    emit RewardsDurationUpdated(rewardsDuration);
  }

  function lock() external onlyOwner isUnlocked {
    emit Locked(block.timestamp, block.timestamp + lockDuration);
    lockTime = block.timestamp;
  }

  function syncWeights(uint256 start, uint256 end) external onlyOwner {
    uint256 poolsCount = poolManager.poolsCount();
    if (end > poolsCount) {
      end = poolsCount;
    }
    for (uint256 i = start; i < end; i++) {
      poolManager.setWeight(poolManager.poolsByIndex(i), poolWeights[i]);
    }
  }

  function setLockDuration(uint256 _lockDuration) external onlyOwner isUnlocked {
    emit LockDurationChanged(lockDuration, _lockDuration);
    lockDuration =  _lockDuration;
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

  function transferPoolManagerOwnership(address to) external onlyOwner {
    poolManager.transferOwnership(to);
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

  modifier isUnlocked() {
    require(block.timestamp >= lockTime.add(lockDuration), "Weights are locked");
    _;
  }

  /* ========== EVENTS ========== */

  event RewardAdded(uint256 reward);
  event Staked(address indexed user, uint256 amount);
  event Withdrawn(address indexed user, uint256 amount);
  event RewardPaid(address indexed user, uint256 reward);
  event RewardsDurationUpdated(uint256 newDuration);
  event Recovered(address token, uint256 amount);
  event Locked(uint256 lockTime, uint256 lockEndTime);
  event LockDurationChanged(uint256 prevLockDuration, uint256 nextLockDuration);
}
