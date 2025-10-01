// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import "forge-std/src/Test.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import { CharacterToken } from "../src/character/CharacterToken.sol";
import { CharacterMinter } from "../src/character/CharacterMinter.sol";

contract CharacterMinterTest is Test {
    using ECDSA for bytes32;

    CharacterToken public token;
    CharacterMinter public minter;

    address public admin;
    address public backendSigner;
    uint256 public backendPk;
    address public minterAddr;

    address public alice;

    function setUp() public {
        admin = makeAddr("Admin");
        alice = makeAddr("Alice");
        (backendSigner, backendPk) = makeAddrAndKey("Backend");

        token = new CharacterToken("Characters", "CHAR");

        // deploy minter and grant MINTER_ROLE to it
        minter = new CharacterMinter(address(token), admin, backendSigner);
        minterAddr = address(minter);

        token.setupRoles(admin, minterAddr);
    }

    function signCid(string memory cid) internal view returns (bytes memory sig) {
        bytes32 ethHash = MessageHashUtils.toEthSignedMessageHash(bytes(cid));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(backendPk, ethHash);
        sig = abi.encodePacked(r, s, v);
    }

    function test_mint_success() public {
        string memory cid = "QmExampleCID123";
        bytes memory sig = signCid(cid);

        vm.prank(alice);
        uint256 tokenId = minter.mintWithSignedCid(cid, sig);
        assertEq(tokenId, 0);
        assertEq(token.ownerOf(tokenId), alice);
        assertEq(token.tokenURI(tokenId), string.concat("ipfs://", cid));
    }

    function test_invalid_signer_reverts() public {
        string memory cid = "QmBadCID";
        // Sign with wrong key over just the CID
        bytes32 ethHash = MessageHashUtils.toEthSignedMessageHash(bytes(cid));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(uint256(0xB0B), ethHash);
        bytes memory badSig = abi.encodePacked(r, s, v);

        vm.prank(alice);
        vm.expectRevert(CharacterMinter.InvalidSignature.selector);
        minter.mintWithSignedCid(cid, badSig);
    }

    function test_replay_nonce_reverts() public {
        string memory cid = "QmReplayCID";
        bytes memory sig = signCid(cid);

        vm.startPrank(alice);
        minter.mintWithSignedCid(cid, sig);
        vm.expectRevert(CharacterMinter.UserAlreadyMinted.selector);
        minter.mintWithSignedCid(cid, sig);
        vm.stopPrank();
    }

    function test_replay_cid_reverts_for_different_user() public {
        string memory cid = "QmReplayCID2";
        bytes memory sig = signCid(cid);

        address bob = makeAddr("Bob");

        vm.prank(alice);
        minter.mintWithSignedCid(cid, sig);

        vm.prank(bob);
        vm.expectRevert(CharacterMinter.AlreadyUsed.selector);
        minter.mintWithSignedCid(cid, sig);
    }
}
