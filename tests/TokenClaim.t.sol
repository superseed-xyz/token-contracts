// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import { Test } from "forge-std/src/Test.sol";
import { console2 } from "forge-std/src/console2.sol";

import { TokenClaim } from "../src/claim/TokenClaim.sol";
import { SuperseedToken } from "../src/token/SuperseedToken.sol";

contract TokenClaimTest is Test {
    TokenClaim public tokenClaim;
    SuperseedToken public superseedToken;

    address public initialOwner = makeAddr("Initial Owner");
    address public alice = makeAddr("Alice");
    address public bob = makeAddr("Bob");
    address public defaultAdmin = makeAddr("Admin");
    address public minter = makeAddr("Minter");
    address public treasury = makeAddr("Treasury");


    function setUp() public {
        superseedToken = new SuperseedToken(defaultAdmin, minter, treasury);
        tokenClaim = new TokenClaim(initialOwner, address(superseedToken), treasury);
    }
}
