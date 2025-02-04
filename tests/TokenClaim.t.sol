// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import { Test } from "forge-std/src/Test.sol";
import { console2 } from "forge-std/src/console2.sol";

import { TokenClaim } from "../src/claim/TokenClaim.sol";

contract TokenClaimTest is Test {
    TokenClaim public tokenClaim;

    function setUp() public {
        tokenClaim = new TokenClaim();
    }
}
