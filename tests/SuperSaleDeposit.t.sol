// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/src/Test.sol";

import { SuperSaleDeposit } from "../src/supersale/SuperSaleDeposit.sol";
import { ERC20Mock } from "../src/supersale/mocks/ERC20Mock.sol";
import { IERC20 } from "../src/supersale/dependencies/openzeppelin/token/ERC20/IERC20.sol";

contract SupersaleDepositTest is Test {
    address public alice = makeAddr("Alice");
    address public bob = makeAddr("Bob");
    address public admin = makeAddr("Admin");
    address public operator = makeAddr("Operator");
    address public treasury = makeAddr("Treasury");

    bytes32 public merkleRoot;
    bytes32[] public proofAlice;
    bytes32[] public proofBob;
    ERC20Mock public usdc;
    ERC20Mock public usdt;
    SuperSaleDeposit public ssd;

    function setUp() public {
        merkleRoot = 0xd3065b0f6565f0bd25fb4a4c8244880cbb025dbee3fca8058e69a8c80ead4379;
        proofAlice.push(0xf21944a07e01d96dde2b17ede609c9175358722d5933b0177f1f978164c35503);
        proofBob.push(0x49167babc98c47d7595b258ed848414135923f3e527a3ddf2c1bc11f74e18053);

        usdc = new ERC20Mock("USD Circle", "USDC", 6);
        usdc.mint(alice, 21_000_000e6);
        usdc.mint(bob, 21_000_000e6);
        usdt = new ERC20Mock("USD Tether", "USDT", 6);
        usdt.mint(alice, 21_000_000e6);
        usdt.mint(bob, 21_000_000e6);

        ssd = new SuperSaleDeposit(
            address(this), admin, operator, treasury, IERC20(address(usdc)), IERC20(address(usdt)), merkleRoot
        );

        vm.startPrank(admin);
        ssd.setSaleSchedule(block.timestamp + 1 days, block.timestamp + 2 days, block.timestamp + 30 days);
        ssd.setSaleParameters(250e6, 20_000_000e6);
        ssd.unpause();
        vm.stopPrank();
    }

    function test_totalSold() public {
        skip(2 days);

        vm.prank(alice);
        usdc.approve(address(ssd), type(uint256).max);

        uint256 amountDeposited;
        uint256 purchasedTokens;
        uint256 prevCap;
        uint256 prevPurchasedTokens;

        for (uint256 i = 0; i < 4; i++) {
            (, uint256 cap) = ssd.tiers(i);
            uint256 tierAmount = cap - prevCap;
            prevCap = cap;

            vm.prank(alice);
            ssd.depositUSDC(tierAmount, proofAlice);
            (amountDeposited, purchasedTokens) = ssd.userDeposits(alice);
            console.log("purchased tier %s: %s", i + 1, (purchasedTokens - prevPurchasedTokens) / 1e18);
            prevPurchasedTokens = purchasedTokens;
        }

        console.log("deposited total:  %s", amountDeposited / 1e6);
        console.log("purchased total:  %s", purchasedTokens / 1e18);
    }

    function test_depositUSDC() public {
        skip(2 days);

        vm.startPrank(alice);
        usdc.approve(address(ssd), type(uint256).max);
        ssd.depositUSDC(6_000_000e6, proofAlice);
        uint256 activeTierIndex = ssd.activeTierIndex();
        assertEq(activeTierIndex, 2);
        vm.stopPrank();
    }
}
