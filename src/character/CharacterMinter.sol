// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { ICharacterToken } from "./CharacterToken.sol";

contract CharacterMinter is AccessControl {
    address public signer;
    ICharacterToken public immutable token;

    event SignerUpdated(address indexed previous, address indexed current);
    event CharacterMinted(address indexed to, uint256 tokenId, string metadataUri);

    error InvalidSignature();
    error AlreadyUsed();
    error UserAlreadyMinted();
    error ZeroAddress();

    mapping(bytes32 => bool) private usedCids;
    mapping(address => bool) private walletMintStatus;

    modifier validateUser() {
        if (walletMintStatus[msg.sender]) revert UserAlreadyMinted();
        _;
    }

    constructor(address token_, address admin_, address signer_) {
        if (token_ == address(0) || admin_ == address(0)) revert ZeroAddress();
        token = ICharacterToken(token_);
        _grantRole(DEFAULT_ADMIN_ROLE, admin_);
        _setSigner(signer_);
    }

    function setSigner(address newSigner) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _setSigner(newSigner);
    }

    function mintWithSignedCid(
        string calldata cid,
        bytes calldata signature
    )
        external
        validateUser
        returns (uint256 tokenId)
    {
        address recipient = msg.sender;
        bytes32 cidKey = keccak256(abi.encodePacked(cid));

        if (usedCids[cidKey]) revert AlreadyUsed();

        _validateSignature(cid, signature);

        // Mark as minted
        walletMintStatus[recipient] = true;
        usedCids[cidKey] = true;

        // Mint using full ipfs URI
        string memory metadataUri = string.concat("ipfs://", cid);
        tokenId = token.mintToWithURI(recipient, metadataUri);

        emit CharacterMinted(recipient, tokenId, metadataUri);
        return tokenId;
    }

    // Private fns
    function _setSigner(address newSigner) private {
        if (newSigner == address(0)) revert ZeroAddress();
        emit SignerUpdated(signer, newSigner);
        signer = newSigner;
    }

    function _validateSignature(string calldata cid, bytes calldata signature) private view {
        bytes32 digest = MessageHashUtils.toEthSignedMessageHash(bytes(cid));
        address _signer = ECDSA.recover(digest, signature);
        if (_signer != signer) revert InvalidSignature();
    }
}
