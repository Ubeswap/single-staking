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

  /**
   * @notice Transfers voting tokens from this out of this Voter. Only callable by the controller
   * @param amount The amount of voting tokens to transfer out.
   */
  function removeVotes(address to, uint256 amount) external onlyController {
    IERC20(address(votingToken)).safeTransfer(to, amount);
  }

  /**
   * @notice Casts vote for/against/abstain a Proposal
   * @param proposalId id of the proposal to vote for/against/abstain
   * @param support - If 0, vote against - If 1, vote for - If 2, abstain
   */
  function castVote(uint256 proposalId, uint8 support) external onlyUser {
    romulusDelegate.castVote(proposalId, support);
  }

  /// @notice Creates a proposal from this Voter
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
   * @notice Delegate votes of Voter to `delegatee`
   * @param delegatee The address to delegate votes to
   */
  function delegate(address delegatee) external onlyUser {
    votingToken.delegate(delegatee);
  }
}
