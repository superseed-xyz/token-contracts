// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import { Test } from "forge-std/src/Test.sol";
import { IAccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { IERC20Errors } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import { SuperseedToken } from "../src/token/SuperseedToken.sol";
import { Common } from "./Common.t.sol";

contract SuperseedTokenTest is Common, Test {
    function setUp() public {
        superseedToken = new SuperseedToken(defaultAdmin, minter, treasury);
    }

    function testInitialSupply() public view {
        uint256 initialSupply = 10_000_000_000 * (10 ** superseedToken.decimals());
        assertEq(superseedToken.balanceOf(treasury), initialSupply);
    }

    function testMint() public {
        vm.prank(minter);
        uint256 amount = 1000 * (10 ** superseedToken.decimals());
        superseedToken.mint(user, amount);
        assertEq(superseedToken.balanceOf(user), amount);
    }

    function testMintNotMinter() public {
        uint256 amount = 1000 * (10 ** superseedToken.decimals());
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, user, superseedToken.MINTER_ROLE()
            )
        );
        superseedToken.mint(user, amount);
    }

    function testMintZeroTokens() public {
        vm.prank(minter);
        uint256 amount = 0;
        superseedToken.mint(user, amount);
        assertEq(superseedToken.balanceOf(user), amount);
    }

    function testMintToZeroAddress() public {
        vm.prank(minter);
        uint256 amount = 1000 * (10 ** superseedToken.decimals());
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidReceiver.selector, address(0)));
        superseedToken.mint(address(0), amount);
    }

    function testTransferToZeroAddress() public {
        uint256 amount = 1000 * (10 ** superseedToken.decimals());
        vm.prank(minter);
        superseedToken.mint(user, amount);
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidReceiver.selector, address(0)));
        superseedToken.transfer(address(0), amount);
    }

    function testTransferMoreThanBalance() public {
        uint256 amount = 1000 * (10 ** superseedToken.decimals());
        vm.prank(minter);
        superseedToken.mint(user, amount);
        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, user, amount, amount + 1)
        );
        superseedToken.transfer(defaultAdmin, amount + 1);
    }

    function testBurnTokens() public {
        uint256 amount = 1000 * (10 ** superseedToken.decimals());
        vm.prank(minter);
        superseedToken.mint(user, amount);
        vm.prank(user);
        superseedToken.burn(amount);
        assertEq(superseedToken.balanceOf(user), 0);
    }
}
