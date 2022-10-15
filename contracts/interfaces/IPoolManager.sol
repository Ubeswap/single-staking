// SPDX-License-Identifier: MIT

pragma solidity ^0.8.3;

interface IPoolManager {
  // Views
  function poolsCount() external view returns (uint256);
  function poolsByIndex(uint256 index) external view returns (address);
  
  // Mutative
  function setWeight (address _stakingToken, uint256 _weight) external;
}