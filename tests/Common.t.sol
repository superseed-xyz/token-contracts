// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import { SuperseedToken } from "../src/token/SuperseedToken.sol";

contract Common {
    SuperseedToken public superseedToken;

    address public constant defaultAdmin = address(0x1);
    address public constant minter = address(0x2);
    address public constant treasury = address(0x3);
    address public constant user = address(0x4);
}
