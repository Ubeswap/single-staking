// SPDX-License-Identifier: MIT

pragma solidity ^0.8.3;

// Inheritance
import "./Owned.sol";

// https://docs.synthetix.io/contracts/source/contracts/rewardsdistributionrecipient
abstract contract RewardsDistributionRecipient is Owned {
  address public rewardsDistribution;

  event RewardsDistributionChanged(
    address indexed previousRewardsDistribution,
    address indexed nextRewardsDistribution
  );

  function notifyRewardAmount(uint256 reward) external virtual;

  modifier onlyRewardsDistribution() {
    require(
      msg.sender == rewardsDistribution,
      "Caller is not RewardsDistribution contract"
    );
    _;
  }

  function setRewardsDistribution(address _rewardsDistribution)
    external
    onlyOwner
  {
    address previousRewardsDistribution = rewardsDistribution;
    rewardsDistribution = _rewardsDistribution;
    emit RewardsDistributionChanged(
      previousRewardsDistribution,
      rewardsDistribution
    );
  }
}
