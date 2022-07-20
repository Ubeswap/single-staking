// SPDX-License-Identifier: MIT

pragma solidity ^0.8.3;

interface IRomulusDelegate {
  function castVote(uint256 proposalId, uint8 support) external;

  function propose( 
        address[] memory targets,
        uint256[] memory values,
        string[] memory signatures,
        bytes[] memory calldatas,
        string memory description) external;
}