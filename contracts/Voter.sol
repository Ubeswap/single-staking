// SPDX-License-Identifier: MIT

pragma solidity ^0.8.3;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@ubeswap/governance/contracts/interfaces/IVotingDelegates.sol";

import "./interfaces/IRomulusDelegate.sol";

contract Voter is Ownable {
    using SafeERC20 for IERC20;

    //uint8 public immutable support;
    IVotingDelegates public immutable votingToken;
    IRomulusDelegate public immutable romulusDelegate;

    constructor(
        //uint8 _support,
        IVotingDelegates _votingToken,
        IRomulusDelegate _romulusDelegate
    ) {
        //support = _support;
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

    //work on adding missing funcitons in romulus
    //update cast vote so that user has to pass in support
    function removeVotes(uint256 amount) external onlyOwner {
        IERC20(address(votingToken)).safeTransfer(msg.sender, amount);
    }

    // function castVote(uint256 proposalId) external {
    //     romulusDelegate.castVote(proposalId, support);
    // }

    function castVote(uint256 proposalId, uint8 support) external {
        romulusDelegate.castVote(proposalId, support);
    }

    function propose(
        address[] memory targets,
        uint256[] memory values,
        string[] memory signatures,
        bytes[] memory calldatas,
        string memory description
    ) external {
        romulusDelegate.propose(
            targets,
            values,
            signatures,
            calldatas,
            description
        );
    }

    //make sure if somebody is calling VotableStakingRewards, only that user can use that voter
    //onlyOwner can propose
    //general idea: only user can propose using their voter
    //in additon to owner we want controller
    //make controllable contract
    //controllable is a standalone contract, constructor takes a controller, sets the controller to be an immutable state variable, creates a modifier (a special function that enforces the msg.sender is equal to controller)
}
