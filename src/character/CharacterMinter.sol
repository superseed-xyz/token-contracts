// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ICharacterToken} from "./CharacterToken.sol";

contract CharacterMinter is AccessControl {
	address public signer;
	ICharacterToken public immutable token;

	event SignerUpdated(address indexed signer);
	event CharacterMinted(address indexed to, uint256 tokenId, string metadataUri);

	error InvalidSignature();
	error AlreadyUsed();
	error ZeroAddress();

	mapping(address => mapping(bytes32 => bool)) private _usedNonces;

	constructor(address token_, address admin_, address signer_) {
		if (token_ == address(0) || admin_ == address(0) || signer_ == address(0)) revert ZeroAddress();
		_grantRole(DEFAULT_ADMIN_ROLE, admin_);
		signer = signer_;
		token = ICharacterToken(token_);
		emit SignerUpdated(signer_);
	}

	function setSigner(address newSigner) external onlyRole(DEFAULT_ADMIN_ROLE) {
		if (newSigner == address(0)) revert ZeroAddress();
		signer = newSigner;
		emit SignerUpdated(newSigner);
	}

	// New mint function that rebuilds and verifies the signed message on-chain.
	// The backend signs: `CID:<cid>;RECIPIENT:<recipient>;NONCE:<nonce>`
	function mintWithSignedCid(
		string calldata cid,
		address recipient,
		string calldata nonce,
		bytes calldata signature
	) external returns (uint256 tokenId) {
		if (recipient == address(0)) revert ZeroAddress();

		// Replay protection: mark nonce as used per recipient
		bytes32 nonceKey = keccak256(abi.encodePacked(nonce));
		if (_usedNonces[recipient][nonceKey]) revert AlreadyUsed();
		_usedNonces[recipient][nonceKey] = true;

		// Rebuild the exact message
		bytes memory message = bytes(
			string.concat(
				"CID:", cid,
				";RECIPIENT:", _toChecksumHex(recipient),
				";NONCE:", nonce
			)
		);

		// Standard Ethereum signed message prefix
		bytes32 digest = MessageHashUtils.toEthSignedMessageHash(message);

		address recovered = ECDSA.recover(digest, signature);
		if (recovered != signer) revert InvalidSignature();

		// Mint using full ipfs URI
		string memory metadataUri = string.concat("ipfs://", cid);
		tokenId = token.mintToWithURI(recipient, metadataUri);
		emit CharacterMinted(recipient, tokenId, metadataUri);
	}

	// Helpers

	function _toChecksumHex(address account) private pure returns (string memory) {
		// Lowercase hex without 0x
		bytes20 data = bytes20(account);
		bytes memory str = new bytes(40);
		for (uint256 i = 0; i < 20; i++) {
			uint8 b = uint8(data[i]);
			str[2 * i] = _HEX_SYMBOLS[b >> 4];
			str[2 * i + 1] = _HEX_SYMBOLS[b & 0x0f];
		}
		// Add 0x prefix and return
		return string(abi.encodePacked("0x", str));
	}

	bytes16 private constant _HEX_SYMBOLS = "0123456789abcdef";
}
