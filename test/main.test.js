/* global artifacts, web3, contract */

require("chai")
  .use(require("bn-chai")(web3.utils.BN))
  .use(require("chai-as-promised"))
  .should();

//const ethers = require('ethers');
//const { ethers } = require("hardhat");
const VotableStakingRewards = artifacts.require("VotableStakingRewards");
const MockRomulus = artifacts.require("MockRomulus");
const MockVotingToken = artifacts.require("MockVotingToken");
const Voter = artifacts.require("Voter");

function encodeParameters(types, values) {
  const abi = new ethers.utils.AbiCoder();
  return abi.encode(types, values);
}

contract("VotableStakingRewards", (accounts) => {
  const amount = 1000;
  let token, stakingRewards;

  before(async () => {
    [sender, a1, proposer, v1, v2, v3, v4, a2] = accounts;
    values = ["0"];
    signatures = ["getBalanceOf(address)"];
    //calldatas = [encodeParameters(['address'], [a1])];

    token = await MockVotingToken.new();
    romulus = await MockRomulus.new(token.address);

    stakingRewards = await VotableStakingRewards.new(
      sender,
      sender,
      token.address,
      token.address,
      romulus.address
    );

    //Token = await ethers.getContractFactory("Token");

  });

  describe("#constructor/stake", () => {
    it("should work", async () => {

      //await stakingRewards.connect(v1).transfer(40);

      const balanceBefores = await token.balanceOf(sender);
      await token.approve(stakingRewards.address, amount);
      const balanceBefore = await token.balanceOf(sender);
      const balanceBeforeV1 = await token.balanceOf(v1);
      await stakingRewards.stake(amount);

  
      voter0 = await Voter.at(await stakingRewards.voters(sender));
      const balanceAfter = await token.balanceOf(sender);

      balanceBefore.sub(balanceAfter).should.be.eq.BN(amount);
      (await stakingRewards.balanceOf(sender)).should.be.eq.BN(amount);
      (await token.balanceOf(stakingRewards.address)).should.be.eq.BN(0);
      (await token.balanceOf(voter0.address)).should.be.eq.BN(amount); // Voter should have all the tokens
      (await token.getCurrentVotes(voter0.address)).should.be.eq.BN(amount);

      console.log(v1);
      //await v1.stake(amount);
    });
  });

  describe("#propose", () => {
    it("should work", async () => {
      await stakingRewards.propose([], [], [], [], "do nothing");
      const proposals = await romulus.proposalsMade();
      (proposals).should.be.eq.BN(1); // Against
    });
  });

  describe("#Voter:castVote", () => {
    it("should work", async () => {

      const proposalId = 4;
      const abstainBefore = await romulus.proposalAbstainVotes(proposalId);
      const forBefore = await romulus.proposalForVotes(proposalId);
      const againstBefore = await romulus.proposalAgainstVotes(proposalId);

      await stakingRewards.castVote(proposalId, 0);
      const abstainAfter = await romulus.proposalAbstainVotes(proposalId);
      const forAfter = await romulus.proposalForVotes(proposalId);
      const againstAfter = await romulus.proposalAgainstVotes(proposalId);

      abstainAfter.sub(abstainBefore).should.be.eq.BN(0);
      forAfter.sub(forBefore).should.be.eq.BN(0);
      againstAfter.sub(againstBefore).should.be.eq.BN(amount);
      console.log(`abstain after: ${abstainAfter}`);
    });
  });

  describe("#exit", () => {
    it("should work", async () => {
      const balanceBefore = await token.balanceOf(sender);
      console.log(`staking rewards addy: ${stakingRewards.address}`);
      console.log(`staking rewards addy: ${stakingRewards}`);
      await stakingRewards.exit();

      const balanceAfter = await token.balanceOf(sender);
      balanceAfter.sub(balanceBefore).should.be.eq.BN(amount);
      (await stakingRewards.balanceOf(sender)).should.be.eq.BN(0);

      // Staking rewards doesn't have any tokens
      (await token.balanceOf(stakingRewards.address)).should.be.eq.BN(0);

      // All voters should have no tokens
      (await token.balanceOf(voter0.address)).should.be.eq.BN(0);
      (await token.getCurrentVotes(voter0.address)).should.be.eq.BN(0);
    });
  });
});
