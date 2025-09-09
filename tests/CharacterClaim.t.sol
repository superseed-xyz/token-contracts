// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import "forge-std/src/Test.sol";
import { MerkleProof } from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import { CharacterToken } from "../src/token/CharacterToken.sol";
import { CharacterClaim } from "../src/claim/CharacterClaim.sol";

contract CharacterClaimTest is Test {
    CharacterToken public token;
    CharacterClaim public claim;

    string public constant NAME = "Tamagotchi";
    string public constant SYMBOL = "TAMAGO";
    string public constant BASE_URI = "https://example.com/metadata/";

    address public admin = makeAddr("Admin");
    address public alice = makeAddr("Alice");
    address public bob = makeAddr("Bob");

    bytes32 public merkleRoot;
    bytes32[] public proofAlice;

    function setUp() public {
        token = new CharacterToken(NAME, SYMBOL, BASE_URI, admin);
        claim = new CharacterClaim(address(token), admin);

        vm.startPrank(admin);
        token.grantRole(token.MINTER_ROLE(), address(claim));
        vm.stopPrank();

        bytes32 leafAlice = keccak256(abi.encodePacked(alice));
        bytes32 leafBob = keccak256(abi.encodePacked(bob));

        bytes32 parent = leafAlice < leafBob
            ? keccak256(abi.encodePacked(leafAlice, leafBob))
            : keccak256(abi.encodePacked(leafBob, leafAlice));
        merkleRoot = parent;
        vm.startPrank(admin);
        claim.setMerkleRoot(merkleRoot);
        vm.stopPrank();

        proofAlice.push(leafBob);
    }

    function test_canClaim_and_claim_flow() public {
        bytes32 leafAlice = keccak256(abi.encodePacked(alice));
        assertTrue(claim.canClaim(alice, proofAlice, leafAlice));

        vm.prank(alice);
        claim.claim(proofAlice, leafAlice);

        assertTrue(claim.hasClaimed(alice));
        assertFalse(claim.canClaim(alice, proofAlice, leafAlice));
        assertEq(token.ownerOf(1), alice);

        vm.prank(alice);
        vm.expectRevert(bytes("Already claimed"));
        claim.claim(proofAlice, leafAlice);
    }

    function test_claim_reverts_with_invalid_proof() public {
        bytes32 leafAlice = keccak256(abi.encodePacked(alice));
        bytes32[] memory invalid = new bytes32[](1);
        invalid[0] = keccak256("wrong");

        vm.prank(alice);
        vm.expectRevert(bytes("Invalid proof"));
        claim.claim(invalid, leafAlice);
    }
}
