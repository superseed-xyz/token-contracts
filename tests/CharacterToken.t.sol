// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import "forge-std/src/Test.sol";
import { IAccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { CharacterToken } from "../src/token/CharacterToken.sol";

contract CharacterTokenTest is Test {
    CharacterToken public token;

    string public constant NAME = "Tamagotchi";
    string public constant SYMBOL = "TAMAGO";
    string public constant BASE_URI = "https://example.com/metadata/";

    address public admin = makeAddr("Admin");
    address public alice = makeAddr("Alice");
    address public bob = makeAddr("Bob");

    function setUp() public {
        token = new CharacterToken(NAME, SYMBOL, BASE_URI, admin);
    }

    function test_adminRolesAssigned() public view {
        assertTrue(token.hasRole(token.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(token.hasRole(token.MINTER_ROLE(), admin));
    }

    function test_mintTo_onlyMinter() public {
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, alice, token.MINTER_ROLE())
        );
        vm.prank(alice);
        token.mintTo(alice);

        vm.prank(admin);
        uint256 tokenId = token.mintTo(alice);
        assertEq(tokenId, 1);
        assertEq(token.ownerOf(1), alice);
    }

    function test_setBaseURI_onlyAdmin() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, alice, token.DEFAULT_ADMIN_ROLE()
            )
        );
        vm.prank(alice);
        token.setBaseURI("ipfs://new/");

        vm.prank(admin);
        token.setBaseURI("ipfs://new/");
    }
}
