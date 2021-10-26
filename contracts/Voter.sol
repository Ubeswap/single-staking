// SPDX-License-Identifier: MIT

pragma solidity ^0.8.3;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./interfaces/IRomulusDelegate.sol";
import "./interfaces/IVotingDelegates.sol";

contract Voter is Ownable {
  using SafeERC20 for IERC20;

  uint8 public immutable support;
  IVotingDelegates public immutable votingToken;
  IRomulusDelegate public immutable romulusDelegate;

  constructor(
    uint8 _support,
    IVotingDelegates _votingToken,
    IRomulusDelegate _romulusDelegate
  ) {
    support = _support;
    votingToken = _votingToken;
    romulusDelegate = _romulusDelegate;

    _votingToken.delegate(address(this));
  }

  function addVotes(uint256 amount) external onlyOwner {
    IERC20(address(votingToken)).safeTransferFrom(
      msg.sender,
      address(this),
      amount
    );
  }

  function removeVotes(uint256 amount) external onlyOwner {
    IERC20(address(votingToken)).safeTransfer(msg.sender, amount);
  }

  function castVote(uint256 proposalId) external {
    romulusDelegate.castVote(proposalId, support);
  }
}
