// SPDX-License-Identifier: MIT
//make all the interactions happen through VoteableStakingRewards, so the frontend doesnt have to worry about two contracts


pragma solidity ^0.8.3;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@ubeswap/governance/contracts/interfaces/IVotingDelegates.sol";
import "./interfaces/IRomulusDelegate.sol";

import "./Controllable.sol";

contract Voter is Ownable {
    using SafeERC20 for IERC20;

    //uint8 public immutable support;
    IVotingDelegates public immutable votingToken;
    IRomulusDelegate public immutable romulusDelegate;
    address public controllerAddress;
    bool public isExist = false;
    uint256 public value;

    constructor(
        IVotingDelegates _votingToken,
        IRomulusDelegate _romulusDelegate
    ) {
        votingToken = _votingToken;
        romulusDelegate = _romulusDelegate;
        _votingToken.delegate(address(this));
        isExist = true;
        value = 1;
    }

    /// @notice
    function addVotes(uint256 amount) external onlyOwner{
        IERC20(address(votingToken)).safeTransferFrom(
            msg.sender,
            address(this),
            amount
        );
    }


    //work on adding missing funcitons in romulus
    //update cast vote so that user has to pass in support
    function removeVotes(uint256 amount) external onlyOwner{
        IERC20(address(votingToken)).safeTransfer(msg.sender, amount);
    }

    function castVote(uint256 proposalId, uint8 support)
        external
        onlyOwner
    {
        romulusDelegate.castVote(proposalId, support);
    }

    function propose(
        address[] memory targets,
        uint256[] memory values,
        string[] memory signatures,
        bytes[] memory calldatas,
        string memory description
    ) external onlyOwner{
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
