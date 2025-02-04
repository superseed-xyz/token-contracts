// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import { Test } from "forge-std/src/Test.sol";
import { console2 } from "forge-std/src/console2.sol";

import { SuperseedToken } from "../src/token/SuperseedToken.sol";

contract SuperseedTokenTest is Test {
    SuperseedToken public superseedToken;

    function setUp() public {
        superseedToken = new SuperseedToken();
    }
}
