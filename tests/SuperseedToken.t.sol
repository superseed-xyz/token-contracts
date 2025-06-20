// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import "forge-std/src/Test.sol";
import { IAccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { IERC20Errors } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { SuperseedToken } from "../src/token/SuperseedToken.sol";

contract SuperseedTokenTest is Test {
    SuperseedToken public superseedToken;
    string public constant TOKEN_NAME = "Superseed";
    string public constant TOKEN_SYMBOL = "SUPR";

    address public alice = makeAddr("Alice");
    address public bob = makeAddr("Bob");
    address public defaultAdmin = makeAddr("Admin");
    address public minter = makeAddr("Minter");
    address public treasury = makeAddr("Treasury");

    function setUp() public {
        superseedToken = new SuperseedToken(TOKEN_NAME, TOKEN_SYMBOL, defaultAdmin, minter, treasury);
    }

    function test_initialSupply() public view {
        uint256 initialSupply = 10_000_000_000e18;
        assertEq(superseedToken.balanceOf(treasury), initialSupply);
    }

    function test_mint() public {
        uint256 amount = 1000e18;
        vm.prank(minter);
        superseedToken.mint(alice, amount);
        assertEq(superseedToken.balanceOf(alice), amount);
    }

    function test_mintNotMinter() public {
        uint256 amount = 1000e18;
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, alice, superseedToken.MINTER_ROLE()
            )
        );
        vm.prank(alice);
        superseedToken.mint(alice, amount);
    }

    function test_mintZeroTokens() public {
        vm.prank(minter);
        uint256 amount = 0;
        superseedToken.mint(alice, amount);
        assertEq(superseedToken.balanceOf(alice), amount);
    }

    function test_mintToZeroAddress() public {
        uint256 amount = 1000e18;
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidReceiver.selector, address(0)));
        vm.prank(minter);
        superseedToken.mint(address(0), amount);
    }

    function test_transferToZeroAddress() public {
        uint256 amount = 1000e18;
        vm.prank(minter);
        superseedToken.mint(alice, amount);
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidReceiver.selector, address(0)));
        superseedToken.transfer(address(0), amount);
    }

    function test_transferMoreThanBalance() public {
        uint256 amount = 1000e18;
        vm.prank(minter);
        superseedToken.mint(alice, amount);
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, alice, amount, amount + 1)
        );
        superseedToken.transfer(defaultAdmin, amount + 1);
    }

    function test_burnTokens() public {
        uint256 amount = 1000e18;
        vm.prank(minter);
        superseedToken.mint(alice, amount);
        vm.prank(alice);
        superseedToken.burn(amount);
        assertEq(superseedToken.balanceOf(alice), 0);
    }
}
