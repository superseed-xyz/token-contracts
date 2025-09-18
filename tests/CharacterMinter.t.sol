// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import "forge-std/src/Test.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import { CharacterToken } from "../src/token/CharacterToken.sol";
import { CharacterMinter } from "../src/claim/CharacterMinter.sol";

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

        token = new CharacterToken("Characters", "CHAR", admin);

        // deploy minter and transfer token ownership so it can mint (onlyOwner)
        minter = new CharacterMinter(address(token), admin, backendSigner);
        minterAddr = address(minter);

        vm.prank(admin);
        token.transferOwnership(minterAddr);
    }

    function signCid(string memory cid) internal view returns (bytes memory sig) {
        bytes memory message = bytes(string.concat("CID:", cid));
        bytes32 ethHash = MessageHashUtils.toEthSignedMessageHash(message);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(backendPk, ethHash);
        sig = abi.encodePacked(r, s, v);
    }

    function test_mint_ipfs_prefixed_uri_success() public {
        string memory cid = "QmExampleCID123";
        string memory uri = string.concat("ipfs://", cid);
        bytes memory sig = signCid(cid);

        vm.prank(alice);
        uint256 tokenId = minter.mintWithSignedMetadata(uri, sig);
        assertEq(tokenId, 0);
        assertEq(token.ownerOf(tokenId), alice);
        assertEq(token.tokenURI(tokenId), uri);
    }

    function test_mint_bare_cid_success() public {
        string memory cid = "QmAnotherCID456";
        string memory uri = cid;
        bytes memory sig = signCid(cid);

        vm.prank(alice);
        uint256 tokenId = minter.mintWithSignedMetadata(uri, sig);
        assertEq(token.ownerOf(tokenId), alice);
        assertEq(token.tokenURI(tokenId), uri);
    }

    function test_invalid_signer_reverts() public {
        string memory cid = "QmBadCID";
        string memory uri = string.concat("ipfs://", cid);
        uint256 wrongPk = 0xB0B;
        bytes memory message = bytes(string.concat("CID:", cid));
        bytes32 ethHash = MessageHashUtils.toEthSignedMessageHash(message);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(wrongPk, ethHash);
        bytes memory badSig = abi.encodePacked(r, s, v);

        vm.prank(alice);
        vm.expectRevert(CharacterMinter.InvalidSignature.selector);
        minter.mintWithSignedMetadata(uri, badSig);
    }
}