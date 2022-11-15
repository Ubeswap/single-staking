// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

import "@openzeppelin/contracts/access/Ownable.sol";

abstract contract IPoolManager is Ownable {
  function poolsCount() external view virtual returns (uint256);

  function poolsByIndex(uint256 index)
    external
    view
    virtual
    returns (address);

  function setWeight(address _stakingToken, uint256 _weight) external virtual;
}
