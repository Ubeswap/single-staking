//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@ubeswap/governance/contracts/UbeToken.sol";

contract MockVotingToken is UbeToken {
  constructor() UbeToken(msg.sender) {}
}
