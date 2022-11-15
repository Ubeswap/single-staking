// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

import "../interfaces/IRomulusDelegate.sol";
import "./MockVotingToken.sol";

contract MockRomulus is IRomulusDelegate {
  mapping(uint256 => uint256) public proposalAgainstVotes;
  mapping(uint256 => uint256) public proposalForVotes;
  mapping(uint256 => uint256) public proposalAbstainVotes;
  uint256 public proposalsMade;

  MockVotingToken public votingToken;

  constructor(MockVotingToken _votingToken) {
    votingToken = _votingToken;
  }

  function castVote(uint256 proposalId, uint8 support) external override {
    uint256 votes = votingToken.getCurrentVotes(msg.sender);
    if (support == 0) {
      proposalAgainstVotes[proposalId] += votes;
    } else if (support == 1) {
      proposalForVotes[proposalId] += votes;
    } else if (support == 2) {
      proposalAbstainVotes[proposalId] += votes;
    }
  }

  function propose(
    address[] memory,
    uint256[] memory,
    string[] memory,
    bytes[] memory,
    string memory
  ) external override {
    proposalsMade += 1;
  }
}
