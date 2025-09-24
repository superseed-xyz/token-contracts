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

        token = new CharacterToken("Characters", "CHAR", admin);

        // deploy minter and transfer token ownership so it can mint (onlyOwner)
        minter = new CharacterMinter(address(token), admin, backendSigner);
        minterAddr = address(minter);

        vm.prank(admin);
        token.transferOwnership(minterAddr);
    }

    function toLowerHex(address account) internal pure returns (string memory) {
        bytes20 data = bytes20(account);
        bytes memory str = new bytes(40);
        bytes16 HEX = "0123456789abcdef";
        for (uint256 i = 0; i < 20; i++) {
            uint8 b = uint8(data[i]);
            str[2 * i] = HEX[b >> 4];
            str[2 * i + 1] = HEX[b & 0x0f];
        }
        return string(abi.encodePacked("0x", str));
    }

    function signCidRecipientNonce(string memory cid, address recipient, string memory nonce)
        internal
        view
        returns (bytes memory sig)
    {
        bytes memory message = bytes(
            string.concat(
                "CID:", cid,
                ";RECIPIENT:", toLowerHex(recipient),
                ";NONCE:", nonce
            )
        );
        bytes32 ethHash = MessageHashUtils.toEthSignedMessageHash(message);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(backendPk, ethHash);
        sig = abi.encodePacked(r, s, v);
    }

    function test_mint_success() public {
        string memory cid = "QmExampleCID123";
        string memory nonce = "n1";
        bytes memory sig = signCidRecipientNonce(cid, alice, nonce);

        vm.prank(alice);
        uint256 tokenId = minter.mintWithSignedCid(cid, alice, nonce, sig);
        assertEq(tokenId, 0);
        assertEq(token.ownerOf(tokenId), alice);
        assertEq(token.tokenURI(tokenId), string.concat("ipfs://", cid));
    }

    function test_invalid_signer_reverts() public {
        string memory cid = "QmBadCID";
        string memory nonce = "n2";

        // Sign with wrong key
        bytes memory message = bytes(
            string.concat(
                "CID:", cid,
                ";RECIPIENT:", toLowerHex(alice),
                ";NONCE:", nonce
            )
        );
        bytes32 ethHash = MessageHashUtils.toEthSignedMessageHash(message);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(uint256(0xB0B), ethHash);
        bytes memory badSig = abi.encodePacked(r, s, v);

        vm.prank(alice);
        vm.expectRevert(CharacterMinter.InvalidSignature.selector);
        minter.mintWithSignedCid(cid, alice, nonce, badSig);
    }

    function test_replay_nonce_reverts() public {
        string memory cid = "QmReplayCID";
        string memory nonce = "replay-1";
        bytes memory sig = signCidRecipientNonce(cid, alice, nonce);

        vm.startPrank(alice);
        minter.mintWithSignedCid(cid, alice, nonce, sig);
        vm.expectRevert(CharacterMinter.AlreadyUsed.selector);
        minter.mintWithSignedCid(cid, alice, nonce, sig);
        vm.stopPrank();
    }
}