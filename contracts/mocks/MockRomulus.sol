// SPDX-License-Identifier: MIT

pragma solidity ^0.8.3;

import "@openzeppelin/contracts/interfaces/IERC20.sol";

contract MockRomulus {
  mapping(uint256 => uint256) public proposalAgainstVotes;
  mapping(uint256 => uint256) public proposalForVotes;
  mapping(uint256 => uint256) public proposalAbstainVotes;

  IERC20 public votingToken;

  constructor(IERC20 _votingToken) {
    votingToken = _votingToken;
  }

  function castVote(uint256 proposalId, uint8 support) external {
    uint256 userBalance = votingToken.balanceOf(msg.sender);
    if (support == 0) {
      proposalAgainstVotes[proposalId] += userBalance;
    } else if (support == 1) {
      proposalForVotes[proposalId] += userBalance;
    } else if (support == 2) {
      proposalAbstainVotes[proposalId] += userBalance;
    }
  }
}

