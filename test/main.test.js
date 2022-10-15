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
  const amount = 1000;
  let token, stakingRewards;

  before(async () => {
    [sender, a1, proposer, v1, v2, v3, v4, a2, a3, a4, a5, a6] = accounts;
    console.log(accounts)
    values = ["0"];
    signatures = ["getBalanceOf(address)"];
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

  describe("#constructor/stake", () => {
    it("should work", async () => {
    
      await token.transferFrom(sender, v1, amount)
      await token.transferFrom(sender, v2, amount)

      const balanceBefore = await token.balanceOf(sender);

      await token.approve(stakingRewards.address, amount*2);
      await token.approve(stakingRewards.address, amount, {from: v1});
      await token.approve(stakingRewards.address, amount, {from: v2});
      await stakingRewards.stake(amount);
      await stakingRewards.stake(amount, {from: v1});
      await stakingRewards.stake(amount, {from: v2});

      voter0 = await Voter.at(await stakingRewards.voters(sender));
      voter1 = await Voter.at(await stakingRewards.voters(v1));
      voter2 = await Voter.at(await stakingRewards.voters(v2));
      

      const balanceAfterV0 = await token.balanceOf(sender);
      console.log(`v0 balance: ${balanceAfterV0} \n`)

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

  describe("#lock", () => {
    it("should work", async () => {
      await stakingRewards.lock();
      assert.equal(await stakingRewards.isLocked(), true);
      
      
    });
  });

  describe("#allocate_pool_weight", () => {
    it("should work", async () => {
      // await token.transferFrom(sender, v1, amount)
      // await token.transferFrom(sender, v2, amount)
      // await token.approve(stakingRewards.address, amount);
      // await token.approve(stakingRewards.address, amount, {from: v1});
      // await token.approve(stakingRewards.address, amount, {from: v2});
      // await stakingRewards.stake(amount);
      // await stakingRewards.stake(amount, {from: v1});
      // await stakingRewards.stake(amount, {from: v2});
      // voter0 = await Voter.at(await stakingRewards.voters(sender));
      // voter1 = await Voter.at(await stakingRewards.voters(v1));    
      // voter2 = await Voter.at(await stakingRewards.voters(v2));


      await stakingRewards.allocate_pool_weight(1, 100);
      await stakingRewards.allocate_pool_weight(1, 100, {from: v1});
      await stakingRewards.allocate_pool_weight(1, 100, {from: v2});
      const poolWeight = await stakingRewards.getPoolWeight(1);
      poolWeight.should.be.eq.BN(300);
    });
  });

  describe("#set_lock duration", () => {
    it ("should work", async () => {
      await stakingRewards.setLockDuration(0);
      assert(await stakingRewards.isLocked() == false);
    });
  });

  describe("#remove_pool_weight", () => {
    it("should work", async () => {
      //await stakingRewards.allocate_pool_weight(1, 100);
      await stakingRewards.remove_pool_weight(1, 100);
      await stakingRewards.remove_pool_weight(1, 100, {from: v1});
      await stakingRewards.remove_pool_weight(1, 100, {from: v2});
      const poolWeight = await stakingRewards.getPoolWeight(1);
      poolWeight.should.be.eq.BN(0);

      try {
        await stakingRewards.remove_pool_weight(1, 100, {from: v2});
        assert.fail("The transaction should have thrown an error");
      }catch (err) {
          assert.include(err.message, "revert", "The error message should contain 'revert'");
      }
    });
  });
});
