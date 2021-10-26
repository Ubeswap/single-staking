/* global artifacts, web3, contract */
require("chai")
  .use(require("bn-chai")(web3.utils.BN))
  .use(require("chai-as-promised"))
  .should();

const VotableStakingRewards = artifacts.require("VotableStakingRewards");
const MockRomulus = artifacts.require("MockRomulus");
const MockVotingToken = artifacts.require("MockVotingToken");
const Voter = artifacts.require("Voter");

contract("VotableStakingRewards", (accounts) => {
  const sender = accounts[0];
  const amount = 1000;
  let token, stakingRewards, voter0, voter1, voter2;

  before(async () => {
    token = await MockVotingToken.new();
    romulus = await MockRomulus.new(token.address);
    stakingRewards = await VotableStakingRewards.new(
      sender,
      sender,
      token.address,
      token.address,
      romulus.address
    );
  });

  describe("#constructor", () => {
    it("should initialize properly", async () => {
      (await stakingRewards.userDelegateIdx(sender)).should.be.eq.BN(0);

      voter0 = await Voter.at(await stakingRewards.delegates(0));
      voter1 = await Voter.at(await stakingRewards.delegates(1));
      voter2 = await Voter.at(await stakingRewards.delegates(2));

      (await voter0.support()).should.be.eq.BN(2); // Abstain
      (await voter1.support()).should.be.eq.BN(1); // For
      (await voter2.support()).should.be.eq.BN(0); // Against
    });
  });

  describe("#stake", () => {
    it("should work", async () => {
      await token.approve(stakingRewards.address, amount);
      const balanceBefore = await token.balanceOf(sender);
      await stakingRewards.stake(amount);
      const balanceAfter = await token.balanceOf(sender);
      balanceBefore.sub(balanceAfter).should.be.eq.BN(amount);
      (await stakingRewards.balanceOf(sender)).should.be.eq.BN(amount);

      // Staking rewards doesn't have any tokens
      (await token.balanceOf(stakingRewards.address)).should.be.eq.BN(0);

      // Voter0 should have all the tokens
      (await token.balanceOf(voter0.address)).should.be.eq.BN(amount);
      (await token.getCurrentVotes(voter0.address)).should.be.eq.BN(amount);

      // Other voters should have no tokens
      (await token.balanceOf(voter1.address)).should.be.eq.BN(0);
      (await token.getCurrentVotes(voter1.address)).should.be.eq.BN(0);
      (await token.balanceOf(voter2.address)).should.be.eq.BN(0);
      (await token.getCurrentVotes(voter2.address)).should.be.eq.BN(0);
    });
  });

  describe("#changeDelegateIdx", () => {
    it("should work", async () => {
      await stakingRewards.changeDelegateIdx(2);

      // Staking rewards doesn't have any tokens
      (await token.balanceOf(stakingRewards.address)).should.be.eq.BN(0);

      // Voter2 should have all the tokens
      (await token.balanceOf(voter2.address)).should.be.eq.BN(amount);
      (await token.getCurrentVotes(voter2.address)).should.be.eq.BN(amount);

      // Other voters should have no tokens
      (await token.balanceOf(voter0.address)).should.be.eq.BN(0);
      (await token.getCurrentVotes(voter0.address)).should.be.eq.BN(0);
      (await token.balanceOf(voter1.address)).should.be.eq.BN(0);
      (await token.getCurrentVotes(voter1.address)).should.be.eq.BN(0);
    });

    it("should fail when out of bounds", async () => {
      await stakingRewards
        .changeDelegateIdx(3)
        .should.be.rejectedWith("newDelegateIdx out of bounds");
    });
  });

  describe("#Voter:castVote", () => {
    it("should work", async () => {
      const proposalId = 4;
      const abstainBefore = await romulus.proposalAbstainVotes(proposalId);
      const forBefore = await romulus.proposalForVotes(proposalId);
      const againstBefore = await romulus.proposalAgainstVotes(proposalId);
      await voter2.castVote(proposalId);
      const abstainAfter = await romulus.proposalAbstainVotes(proposalId);
      const forAfter = await romulus.proposalForVotes(proposalId);
      const againstAfter = await romulus.proposalAgainstVotes(proposalId);

      abstainAfter.sub(abstainBefore).should.be.eq.BN(0);
      forAfter.sub(forBefore).should.be.eq.BN(0);
      againstAfter.sub(againstBefore).should.be.eq.BN(amount);
    });
  });

  describe("#exit", () => {
    it("should work", async () => {
      const balanceBefore = await token.balanceOf(sender);
      await stakingRewards.exit();
      const balanceAfter = await token.balanceOf(sender);
      balanceAfter.sub(balanceBefore).should.be.eq.BN(amount);
      (await stakingRewards.balanceOf(sender)).should.be.eq.BN(0);

      // Staking rewards doesn't have any tokens
      (await token.balanceOf(stakingRewards.address)).should.be.eq.BN(0);

      // All voters should have no tokens
      (await token.balanceOf(voter0.address)).should.be.eq.BN(0);
      (await token.getCurrentVotes(voter0.address)).should.be.eq.BN(0);
      (await token.balanceOf(voter1.address)).should.be.eq.BN(0);
      (await token.getCurrentVotes(voter1.address)).should.be.eq.BN(0);
      (await token.balanceOf(voter2.address)).should.be.eq.BN(0);
      (await token.getCurrentVotes(voter2.address)).should.be.eq.BN(0);
    });
  });
});
