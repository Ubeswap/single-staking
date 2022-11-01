/* global artifacts, web3, contract */
require("chai")
  .use(require("bn-chai")(web3.utils.BN))
  .use(require("chai-as-promised"))
  .should();

const VotableStakingRewards = artifacts.require("VotableStakingRewards");
const MockRomulus = artifacts.require("MockRomulus");
const MockVotingToken = artifacts.require("MockVotingToken");
const MockPoolManager = artifacts.require("MockPoolManager");
const Voter = artifacts.require("Voter");

rpc = ({ method, params }) => {
  return new Promise((resolve, reject) => {
    web3.currentProvider.send(
      {
        jsonrpc: "2.0",
        method,
        params,
      },
      (err, result) => {
        if (err) {
          return reject(err);
        }
        return resolve(result.result);
      }
    );
  });
};

const AGAINST = 0;
const FOR = 1;
const ABSTAIN = 2;

contract("VotableStakingRewards", (accounts) => {
  let token, stakingRewards, poolManager, voter0, voter1, voter2;

  before(async () => {
    [sender, a1, proposer, v1, v2, v3, v4, stakingToken1, stakingToken2] =
      accounts;
    values = ["0"];
    signatures = ["getBalanceOf(address)"];
    token = await MockVotingToken.new();
    romulus = await MockRomulus.new(token.address);

    poolManager = await MockPoolManager.new();
    await poolManager.addPool(stakingToken1);
    await poolManager.addPool(stakingToken2);
    stakingRewards = await VotableStakingRewards.new(
      sender,
      sender,
      token.address,
      token.address,
      romulus.address,
      poolManager.address,
      60 * 60 * 24 * 6 // 6 days
    );
  });

  describe("#constructor/stake", () => {
    it("should work", async () => {
      await token.transferFrom(sender, v1, 50);
      await token.transferFrom(sender, v2, 25);

      await token.approve(stakingRewards.address, 100);
      await token.approve(stakingRewards.address, 50, { from: v1 });
      await token.approve(stakingRewards.address, 25, { from: v2 });

      const balanceBefore = await token.balanceOf(sender);
      await stakingRewards.stake(100);
      const balanceAfter = await token.balanceOf(sender);
      balanceBefore.sub(balanceAfter).should.be.eq.BN(100);
      (await stakingRewards.balanceOf(sender)).should.be.eq.BN(100);
      voter0 = await Voter.at(await stakingRewards.voters(sender));
      (await voter0.controller()).should.be.equal(stakingRewards.address);
      (await voter0.user()).should.be.equal(sender);
      (await token.balanceOf(voter0.address)).should.be.eq.BN(100);
      (await token.getCurrentVotes(voter0.address)).should.be.eq.BN(100);

      await stakingRewards.stake(50, { from: v1 });
      voter1 = await Voter.at(await stakingRewards.voters(v1));
      (await voter1.controller()).should.be.equal(stakingRewards.address);
      (await voter1.user()).should.be.equal(v1);

      await stakingRewards.stake(25, { from: v2 });
      voter2 = await Voter.at(await stakingRewards.voters(v2));
      (await voter2.controller()).should.be.equal(stakingRewards.address);
      (await voter2.user()).should.be.equal(v2);

      (await token.balanceOf(stakingRewards.address)).should.be.eq.BN(0);
    });
  });

  describe("voting", () => {
    it("should let user delegate", async () => {
      (await token.getCurrentVotes(voter2.address)).should.be.eq.BN(25);
      await voter0.delegate(voter2.address);
      (await token.getCurrentVotes(voter2.address)).should.be.eq.BN(125);
    });

    it("does not let non-user delegate", async () => {
      await voter0
        .delegate(v2, { from: v2 })
        .should.be.rejectedWith("Voter: only user");
    });

    it("should let user propose", async () => {
      await voter0.propose(
        [token.address],
        values,
        signatures,
        [],
        "do nothing",
        { from: sender }
      );
      await voter1.propose(
        [token.address],
        values,
        signatures,
        [],
        "do nothing",
        { from: v1 }
      );
      await voter2.propose(
        [token.address],
        values,
        signatures,
        [],
        "do nothing",
        { from: v2 }
      );
      (await romulus.proposalsMade()).should.be.eq.BN(3);
    });

    it("does not let non-user propose", async () => {
      await voter0
        .propose([token.address], values, signatures, [], "do nothing", {
          from: v1,
        })
        .should.be.rejectedWith("Voter: only user");
    });

    const proposal0 = 0;

    it("should let user vote", async () => {
      const abstainBefore = await romulus.proposalAbstainVotes(proposal0);
      const forBefore = await romulus.proposalForVotes(proposal0);
      const againstBefore = await romulus.proposalAgainstVotes(proposal0);

      await voter0.castVote(proposal0, AGAINST);
      await voter1.castVote(proposal0, FOR, { from: v1 });
      await voter2.castVote(proposal0, ABSTAIN, { from: v2 });

      const abstainAfter = await romulus.proposalAbstainVotes(proposal0);
      const forAfter = await romulus.proposalForVotes(proposal0);
      const againstAfter = await romulus.proposalAgainstVotes(proposal0);

      abstainAfter.sub(abstainBefore).should.be.eq.BN(125);
      forAfter.sub(forBefore).should.be.eq.BN(50);
      againstAfter.sub(againstBefore).should.be.eq.BN(0);
    });

    it("does not let non-user vote", async () => {
      await voter0
        .castVote(proposal0, FOR, {
          from: v1,
        })
        .should.be.rejectedWith("Voter: only user");
    });

    it("does not let non-controller removeVotes", async () => {
      await voter0
        .removeVotes(sender, 100)
        .should.be.rejectedWith("Voter: only controller");
    });
  });

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
        .should.be.rejectedWith(
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

    it("does not let non-owner syncWeights", async () => {
      await stakingRewards
        .syncWeights(0, 2, { from: v1 })
        .should.be.rejectedWith(
          "Only the contract owner may perform this action"
        );
    });

    it("lets owner sync weights", async () => {
      (await poolManager.weights(0)).should.be.eq.BN(0);
      (await poolManager.weights(1)).should.be.eq.BN(0);
      await stakingRewards.syncWeights(0, 2);
      (await poolManager.weights(0)).should.be.eq.BN(0);
      (await poolManager.weights(1)).should.be.eq.BN(5);
    });

    it("does not let non-owner lock", async () => {
      await stakingRewards
        .lock({ from: v1 })
        .should.be.rejectedWith(
          "Only the contract owner may perform this action"
        );
      (await stakingRewards.isLocked()).should.be.false;
    });

    it("lets the owner lock", async () => {
      (await stakingRewards.isLocked()).should.be.false;
      await stakingRewards.lock();
      (await stakingRewards.isLocked()).should.be.true;
    });

    it("does not allow double locking", async () => {
      await stakingRewards.lock().should.be.rejectedWith("Weights are locked");
    });

    it("does not allow updating lockDuration", async () => {
      await stakingRewards
        .setLockDuration(1)
        .should.be.rejectedWith("Weights are locked");
    });

    it("does not allow removing pool weights while locked", async () => {
      await stakingRewards
        .removePoolWeight(1, 1)
        .should.be.rejectedWith("Weights are locked");
    });

    it("only allows withdrawals for unlocked balance", async () => {
      await stakingRewards
        .withdraw(100)
        .should.be.rejectedWith("Withdrawing more than available");

      const stakingBalanceBefore = await stakingRewards.balanceOf(sender);
      const tokenBalanceBefore = await token.balanceOf(sender);
      await stakingRewards.withdraw(99);
      const stakingBalanceAfter = await stakingRewards.balanceOf(sender);
      const tokenBalanceAfter = await token.balanceOf(sender);
      stakingBalanceBefore.sub(stakingBalanceAfter).should.be.eq.BN(99);
      tokenBalanceAfter.sub(tokenBalanceBefore).should.be.eq.BN(99);
    });

    it("unlocks after 100 seconds", async () => {
      await rpc({ method: "evm_increaseTime", params: [100] });
      await rpc({ method: "evm_mine" });
      (await stakingRewards.isLocked()).should.be.false;
    });
  });
});
