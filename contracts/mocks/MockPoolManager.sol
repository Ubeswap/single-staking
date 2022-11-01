// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

import "../interfaces/IPoolManager.sol";

contract MockPoolManager is IPoolManager {

  uint256 public override poolsCount;
  mapping(uint256 => address) public override poolsByIndex;
  mapping(address => uint256) public poolToIndex;
  mapping(uint256 => uint256) public weights;

  constructor() {}

  function addPool(address _stakingToken) external onlyOwner {
    poolToIndex[_stakingToken] = poolsCount;
    poolsByIndex[poolsCount] = _stakingToken;
    poolsCount++;
  }

  function setWeight(address _stakingToken, uint256 _weight) external onlyOwner override {
    uint256 index = poolToIndex[_stakingToken];
    require(poolsByIndex[index] == _stakingToken, "Pool not found");
    weights[index] = _weight;
  }
}
