// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

interface ICharacterToken {
    function mintToWithURI(address to, string calldata tokenURI_) external returns (uint256 tokenId);
}

contract CharacterMinter is AccessControl {
    address public signer;
    ICharacterToken public immutable token;
    mapping(bytes32 => bool) public used;

    event SignerUpdated(address indexed signer);
    event CharacterMinted(address indexed to, uint256 tokenId, string metadataUri);

    error InvalidSignature();
    error AlreadyUsed();
    error ZeroAddress();

    constructor(address token_, address admin, address signer_) {
        if (token_ == address(0) || admin == address(0) || signer_ == address(0)) revert ZeroAddress();
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        signer = signer_;
        token = ICharacterToken(token_);
        emit SignerUpdated(signer_);
    }

    function setSigner(address newSigner) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (newSigner == address(0)) revert ZeroAddress();
        signer = newSigner;
        emit SignerUpdated(newSigner);
    }

    function mintWithSignedMetadata(string calldata metadataUri, bytes calldata signature)
        external
        returns (uint256 tokenId)
    {
        string memory cid = _cidFromUri(metadataUri);

        bytes memory message = bytes(string.concat("CID:", cid));
        bytes32 digest = MessageHashUtils.toEthSignedMessageHash(message);

        address recovered = ECDSA.recover(digest, signature);
        if (recovered != signer) revert InvalidSignature();

        tokenId = token.mintToWithURI(msg.sender, metadataUri);
        emit CharacterMinted(msg.sender, tokenId, metadataUri);
    }

    function _cidFromUri(string memory uri) private pure returns (string memory) {
        bytes memory b = bytes(uri);
        bytes memory prefix = bytes("ipfs://");
        if (b.length >= prefix.length) {
            bool hasPrefix = true;
            for (uint256 i = 0; i < prefix.length; i++) {
                if (b[i] != prefix[i]) {
                    hasPrefix = false;
                    break;
                }
            }
            if (hasPrefix) {
                uint256 cidLen = b.length - prefix.length;
                bytes memory cidBytes = new bytes(cidLen);
                for (uint256 j = 0; j < cidLen; j++) {
                    cidBytes[j] = b[j + prefix.length];
                }
                return string(cidBytes);
            }
        }
        return uri;
    }
}


