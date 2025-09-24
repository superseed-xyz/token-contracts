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

    function mintWithSignedCid(string calldata cid, bytes calldata signature)
        external
        returns (uint256 tokenId)
    {
        bytes32 digest = MessageHashUtils.toEthSignedMessageHash(bytes(cid));

        address recovered = ECDSA.recover(digest, signature);
        if (recovered != signer) revert InvalidSignature();

        string memory metadataUri = string.concat("ipfs://", cid);
        tokenId = token.mintToWithURI(msg.sender, metadataUri);
        emit CharacterMinted(msg.sender, tokenId, metadataUri);
    }
}


