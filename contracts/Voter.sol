// SPDX-License-Identifier: MIT

pragma solidity ^0.8.3;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@ubeswap/governance/contracts/interfaces/IVotingDelegates.sol";

import "./interfaces/IRomulusDelegate.sol";

contract Voter {
  using SafeERC20 for IERC20;

  address public immutable controller;
  address public immutable user;
  IVotingDelegates public immutable votingToken;
  IRomulusDelegate public immutable romulusDelegate;

  modifier onlyController() {
    require(msg.sender == controller, "Voter: only controller");
    _;
  }

  modifier onlyUser() {
    require(msg.sender == user, "Voter: only user");
    _;
  }

  constructor(
    address _controller,
    address _user,
    IVotingDelegates _votingToken,
    IRomulusDelegate _romulusDelegate
  ) {
    controller = _controller;
    user = _user;
    votingToken = _votingToken;
    romulusDelegate = _romulusDelegate;
    _votingToken.delegate(address(this));
  }

  function removeVotes(address to, uint256 amount) external onlyController {
    IERC20(address(votingToken)).safeTransfer(to, amount);
  }

  /**
   * @notice Casts vote for/against/abstain a Proposal
   * @param proposalId id of the proposal to vote for/against/abstain
   * @param support AGAINST=0 ; 1=FOR ; 2=ABSTAIN
   */
  function castVote(uint256 proposalId, uint8 support) external onlyUser {
    romulusDelegate.castVote(proposalId, support);
  }

  /// @notice Creates a proposal from this Voter. Only callable by the Voter's user.
  function propose(
    address[] memory targets,
    uint256[] memory values,
    string[] memory signatures,
    bytes[] memory calldatas,
    string memory description
  ) external onlyUser {
      romulusDelegate.propose(
      targets,
      values,
      signatures,
      calldatas,
      description
    );
  }

  /**
   * @notice Delegate votes of Voter to `delegatee`. Only callable by the Voter's user.
   * @param delegatee The address to delegate votes to
   */
  function delegate(address delegatee) external onlyUser {
    votingToken.delegate(delegatee);
  }
}
