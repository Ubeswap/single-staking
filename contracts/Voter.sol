// SPDX-License-Identifier: MIT

pragma solidity ^0.8.3;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@ubeswap/governance/contracts/interfaces/IVotingDelegates.sol";

import "./interfaces/IRomulusDelegate.sol";

contract Voter is Ownable {
  using SafeERC20 for IERC20;

  address public controllerAddress;
  IVotingDelegates public immutable votingToken;
  IRomulusDelegate public immutable romulusDelegate;

  constructor(
    IVotingDelegates _votingToken,
    IRomulusDelegate _romulusDelegate
  ) {
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

  function castVote(uint256 proposalId, uint8 support) external onlyOwner {
    romulusDelegate.castVote(proposalId, support);
  }

  function propose(
    address[] memory targets,
    uint256[] memory values,
    string[] memory signatures,
    bytes[] memory calldatas,
    string memory description
    ) external onlyOwner {
      romulusDelegate.propose(
      targets,
      values,
      signatures,
      calldatas,
      description
    );
  }
}
