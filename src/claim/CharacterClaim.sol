// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

interface ICharacterToken {
    function mintToWithURI(address to, string calldata tokenURI_) external returns (uint256);
}

contract CharacterClaim is AccessControl {
    bytes32 public constant ROOT_UPDATER_ROLE = keccak256("ROOT_UPDATER_ROLE");
    bytes32 public merkleRoot;
    ICharacterToken public immutable token;

    event Claimed(address indexed account, uint256 tokenId);
    event MerkleRootUpdated(bytes32 newRoot);

    mapping(address => bool) public hasClaimed;

    constructor(address tokenAddress, address admin) {
        token = ICharacterToken(tokenAddress);
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(ROOT_UPDATER_ROLE, admin);
    }

    function setMerkleRoot(bytes32 newRoot) external onlyRole(ROOT_UPDATER_ROLE) {
        merkleRoot = newRoot;
        emit MerkleRootUpdated(newRoot);
    }

    function canClaim(address account, bytes32[] calldata proof, bytes32 leaf) public view returns (bool) {
        if (hasClaimed[account]) return false;
        return MerkleProof.verifyCalldata(proof, merkleRoot, leaf);
    }

    function claim(bytes32[] calldata proof, bytes32 leaf, string calldata tokenURI_) external {
        require(!hasClaimed[msg.sender], "Already claimed");
        require(MerkleProof.verifyCalldata(proof, merkleRoot, leaf), "Invalid proof");

        hasClaimed[msg.sender] = true;
        uint256 tokenId = token.mintToWithURI(msg.sender, tokenURI_);
        emit Claimed(msg.sender, tokenId);
    }
}
