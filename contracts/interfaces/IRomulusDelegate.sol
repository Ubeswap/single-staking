// SPDX-License-Identifier: MIT

pragma solidity ^0.8.3;

interface IRomulusDelegate {
  function castVote(uint256 proposalId, uint8 support) external;
}
