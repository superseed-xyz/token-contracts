// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/src/Test.sol";

import { SuperSaleDeposit } from "../src/supersale/SuperSaleDeposit.sol";
import { ERC20Mock } from "../src/supersale/mocks/ERC20Mock.sol";
import { IERC20 } from "../src/supersale/dependencies/openzeppelin/token/ERC20/IERC20.sol";

contract TokenClaimEndToEndTest is Test { }
