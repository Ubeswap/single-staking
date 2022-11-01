const { assert } = require("chai");

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
  const amount = 100;
  let token, stakingRewards;

  before(async () => {
    [sender, a1, proposer, v1, v2, v3, v4, a2, a3, a4, a5, a6] = accounts;
    values = ["0"];
    signatures = ["getBalanceOf(address)"];
    token = await MockVotingToken.new();
    romulus = await MockRomulus.new(token.address);

    stakingRewards = await VotableStakingRewards.new(
      sender,
      sender,
      token.address,
      token.address,
      romulus.address,
      sender, // TODO: MockPoolManager
      60 * 60 * 24 * 6 // 6 days
    );
  });

  describe("#constructor/stake", () => {
    it("should work", async () => {
      await token.transferFrom(sender, v1, amount);
      await token.transferFrom(sender, v2, amount);

      const balanceBefore = await token.balanceOf(sender);

      await token.approve(stakingRewards.address, amount * 2);
      await token.approve(stakingRewards.address, amount, { from: v1 });
      await token.approve(stakingRewards.address, amount, { from: v2 });
      await stakingRewards.stake(amount);
      await stakingRewards.stake(amount, { from: v1 });
      await stakingRewards.stake(amount, { from: v2 });

      voter0 = await Voter.at(await stakingRewards.voters(sender));
      voter1 = await Voter.at(await stakingRewards.voters(v1));
      voter2 = await Voter.at(await stakingRewards.voters(v2));

      const balanceAfterV0 = await token.balanceOf(sender);

      balanceBefore.sub(balanceAfterV0).should.be.eq.BN(amount);
      (await stakingRewards.balanceOf(sender)).should.be.eq.BN(amount);

      (await token.balanceOf(stakingRewards.address)).should.be.eq.BN(0);
      (await token.balanceOf(voter0.address)).should.be.eq.BN(amount);
      (await token.getCurrentVotes(voter0.address)).should.be.eq.BN(amount);
    });
  });

  // describe("#propose", () => {
  //   it("should work", async () => {
  //     await stakingRewards.propose([], [], [], [], "do nothing", {from: sender});
  //     await stakingRewards.propose([], [], [], [], "do nothing", {from: v1});
  //     await stakingRewards.propose([], [], [], [], "do nothing", {from: v2});
  //     const proposals = await romulus.proposalsMade();
  //     (proposals).should.be.eq.BN(3); // Against
  //   });
  // });

  // describe("#Voter:castVote", () => {
  //   it("should work", async () => {

  //     const proposalIdV0 = 0;
  //     const proposalIdV1 = 1;
  //     const proposalIdV2 = 2;
  //     const abstainBeforeV0 = await romulus.proposalAbstainVotes(proposalIdV0);
  //     const forBeforeV0 = await romulus.proposalForVotes(proposalIdV0);
  //     const againstBeforeV0 = await romulus.proposalAgainstVotes(proposalIdV0);
  //     const abstainBeforeV1 = await romulus.proposalAbstainVotes(proposalIdV1);
  //     const forBeforeV1 = await romulus.proposalForVotes(proposalIdV1);
  //     const againstBeforeV1 = await romulus.proposalAgainstVotes(proposalIdV1);
  //     const abstainBeforeV2 = await romulus.proposalAbstainVotes(proposalIdV2);
  //     const forBeforeV2 = await romulus.proposalForVotes(proposalIdV2);
  //     const againstBeforeV2 = await romulus.proposalAgainstVotes(proposalIdV2);

  //     await stakingRewards.castVote(proposalIdV0, 0);
  //     await stakingRewards.castVote(proposalIdV1, 1);
  //     await stakingRewards.castVote(proposalIdV2, 2);
  //     const abstainAfterV0 = await romulus.proposalAbstainVotes(proposalIdV0);
  //     const forAfterV0 = await romulus.proposalForVotes(proposalIdV0);
  //     const againstAfterV0 = await romulus.proposalAgainstVotes(proposalIdV0);
  //     const abstainAfterV1 = await romulus.proposalAbstainVotes(proposalIdV1);
  //     const forAfterV1 = await romulus.proposalForVotes(proposalIdV1);
  //     const againstAfterV1 = await romulus.proposalAgainstVotes(proposalIdV1);
  //     const abstainAfterV2 = await romulus.proposalAbstainVotes(proposalIdV2);
  //     const forAfterV2 = await romulus.proposalForVotes(proposalIdV2);
  //     const againstAfterV2 = await romulus.proposalAgainstVotes(proposalIdV2);

  //     abstainAfterV0.sub(abstainBeforeV0).should.be.eq.BN(0);
  //     forAfterV0.sub(forBeforeV0).should.be.eq.BN(0);
  //     againstAfterV0.sub(againstBeforeV0).should.be.eq.BN(amount);

  //     abstainAfterV1.sub(abstainBeforeV1).should.be.eq.BN(0);
  //     forAfterV1.sub(forBeforeV1).should.be.eq.BN(amount);
  //     againstAfterV1.sub(againstBeforeV1).should.be.eq.BN(0);

  //     abstainAfterV2.sub(abstainBeforeV2).should.be.eq.BN(amount);
  //     forAfterV2.sub(forBeforeV2).should.be.eq.BN(0);
  //     againstAfterV2.sub(againstBeforeV2).should.be.eq.BN(0);
  //   });
  // });

  // describe("#exit", () => {
  //   it("should work", async () => {
  //     const balanceBefore = await token.balanceOf(sender);
  //     await stakingRewards.exit({from: sender});
  //     await stakingRewards.exit({from: v1});
  //     await stakingRewards.exit({from: v2});

  //     const balanceAfter = await token.balanceOf(sender);
  //     balanceAfter.sub(balanceBefore).should.be.eq.BN(amount);
  //     (await stakingRewards.balanceOf(sender)).should.be.eq.BN(0);

  //     // Staking rewards doesn't have any tokens
  //     (await token.balanceOf(stakingRewards.address)).should.be.eq.BN(0);

  //     // All voters should have no tokens
  //     (await token.balanceOf(voter0.address)).should.be.eq.BN(0);
  //     (await token.getCurrentVotes(voter0.address)).should.be.eq.BN(0);
  //     (await token.balanceOf(voter1.address)).should.be.eq.BN(0);
  //     (await token.getCurrentVotes(voter1.address)).should.be.eq.BN(0);
  //     (await token.balanceOf(voter2.address)).should.be.eq.BN(0);
  //     (await token.getCurrentVotes(voter2.address)).should.be.eq.BN(0);
  //   });
  // });

  describe("weights and locking", () => {
    it("lets owner update lockDuration", async () => {
      await stakingRewards.setLockDuration(100);
      (await stakingRewards.lockDuration()).should.be.eq.BN(100);
    });

    it("does not let non-owner update lockDuration", async () => {
      await stakingRewards
        .setLockDuration(100, { from: v1 })
        .should.be.revertedWith(
          "Only the contract owner may perform this action"
        );
    });

    it("lets users allocate weights", async () => {
      await stakingRewards.allocatePoolWeight(1, 1);
      await stakingRewards.allocatePoolWeight(1, 2, { from: v1 });
      await stakingRewards.allocatePoolWeight(1, 3, { from: v2 });

      (await stakingRewards.userWeights(sender, 1)).should.be.eq.BN(1);
      (await stakingRewards.userLocked(sender)).should.be.eq.BN(1);

      (await stakingRewards.userWeights(v1, 1)).should.be.eq.BN(2);
      (await stakingRewards.userLocked(v1)).should.be.eq.BN(2);

      (await stakingRewards.userWeights(v2, 1)).should.be.eq.BN(3);
      (await stakingRewards.userLocked(v2)).should.be.eq.BN(3);

      (await stakingRewards.poolWeights(1)).should.be.eq.BN(6);
    });

    it("lets users remove weights while unlocked", async () => {
      await stakingRewards.removePoolWeight(1, 1, { from: v2 });
      (await stakingRewards.userWeights(v2, 1)).should.be.eq.BN(2);
      (await stakingRewards.userLocked(v2)).should.be.eq.BN(2);
      (await stakingRewards.poolWeights(1)).should.be.eq.BN(5);
    });

    it("does not let non-owner lock", async () => {
      await stakingRewards
        .lock({ from: v1 })
        .should.be.revertedWith(
          "Only the contract owner may perform this action"
        );
      (await stakingRewards.isLocked()).should.be.false;
    });

    it("lets the owner lock", async () => {
      await stakingRewards.lock();
      (await stakingRewards.isLocked()).should.be.true;
    });

    it("does not allow double locking", async () => {
      await stakingRewards.lock().should.be.revertedWith("Weights are locked");
    });

    it("does not allow removing pool weights while locked", async () => {
      await stakingRewards
        .removePoolWeight(1, 1)
        .should.be.revertedWith("Weights are locked");
    });

    it("only allows withdrawals for unlocked balance", async () => {
      await stakingRewards
        .withdraw(100)
        .should.be.revertedWith("Withdrawing more than available");

      const stakingBalanceBefore = await stakingRewards.balanceOf(sender);
      const tokenBalanceBefore = await token.balanceOf(sender);
      await stakingRewards.withdraw(99);
      const stakingBalanceAfter = await stakingRewards.balanceOf(sender);
      const tokenBalanceAfter = await token.balanceOf(sender);
      stakingBalanceBefore.sub(stakingBalanceAfter).should.be.eq.BN(99);
      tokenBalanceAfter.sub(tokenBalanceBefore).should.be.eq.BN(99);
    });
  });
});
