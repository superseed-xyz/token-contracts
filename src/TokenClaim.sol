// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract TokenClaim is Ownable {
    /*//////////////////////////////////////////////////////////////
                            LIBRARIES
    //////////////////////////////////////////////////////////////*/

    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    IERC20 public immutable token; // Token to be claimed
    address public immutable treasury; // Treasury multisig holding the tokens
    bytes32 public merkleRoot; // Root of the Merkle Tree
    mapping(address => bool) public hasClaimed; // Track claimed addresses

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event TokensClaimed(address indexed claimant, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error InvalidInput(string _input);
    error InvalidMerkleProof();
    error AlreadyClaimed();
    
    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address _initialOwner, address _token, address _treasury) Ownable(_initialOwner) {
        token = IERC20(_token);
        treasury = _treasury;
    }

    /**
     * @dev Set the Merkle Root
     * @param _merkleRoot The root of the Merkle Tree
     */
    function setMerkleRoot(bytes32 _merkleRoot) external onlyOwner {
        if (_merkleRoot == bytes32(0)) revert InvalidInput("_merkleRoot");

        merkleRoot = _merkleRoot;
    }

    /**
     * @dev Claim tokens
     * @param _amount Amount of tokens to claim
     * @param _merkleProof Merkle proof to validate the claim
     */
    function claim(uint256 _amount, bytes32[] calldata _merkleProof) external {
        if (hasClaimed[msg.sender]) revert AlreadyClaimed();
        if (_amount == 0) revert InvalidInput("_amount == 0");

        // Verify the Merkle proof
        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(msg.sender, _amount))));

        if (!MerkleProof.verify(_merkleProof, merkleRoot, leaf)) revert InvalidMerkleProof();

        hasClaimed[msg.sender] = true;

        // Transfer tokens to the claimant
        token.safeTransferFrom(treasury, msg.sender, _amount);

        emit TokensClaimed(msg.sender, _amount);
    }

    function withdraw(address _to, IERC20 _asset) external onlyOwner {
        uint256 balance = _asset.balanceOf(address(this));
        if (balance == 0) revert InvalidInput("no balance");

        _asset.safeTransfer(_to, balance);
    }
}
