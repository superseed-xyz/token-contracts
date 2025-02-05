// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import { Test } from "forge-std/src/Test.sol";
import { console2 } from "forge-std/src/console2.sol";

import { TokenClaim } from "../src/claim/TokenClaim.sol";
import { SuperseedToken } from "../src/token/SuperseedToken.sol";
import { Common } from "./Common.t.sol";

contract TokenClaimTest is Common, Test {
    TokenClaim public tokenClaim;
    address public initialOwner = address(0x1);

    function setUp() public {
        superseedToken = new SuperseedToken(defaultAdmin, minter, treasury);
        tokenClaim = new TokenClaim(initialOwner, address(superseedToken), treasury);
    }
}
