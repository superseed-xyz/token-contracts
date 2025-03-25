// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { MerkleProof } from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

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
    event MerkleRootUpdated(bytes32 prevMerkleRoot, bytes32 newMerkleRoot);

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error ZeroAddress();
    error AlreadyClaimed();
    error AmountIsZero();
    error InvalidMerkleProof();
    error EmptyMerkleRoot();
    error ZeroBalanceToken(address token);

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address _initialOwner, address _token, address _treasury, bytes32 _merkleRoot) Ownable(_initialOwner) {
        if (_token == address(0)) revert ZeroAddress();
        if (_treasury == address(0)) revert ZeroAddress();

        token = IERC20(_token);
        treasury = _treasury;

        _setMerkleRoot(_merkleRoot);
    }

    /**
     * @dev Set the Merkle Root
     * @param _merkleRoot The root of the Merkle Tree
     */
    function setMerkleRoot(bytes32 _merkleRoot) external onlyOwner {
        _setMerkleRoot(_merkleRoot);
    }

    /**
     * @dev Claim tokens
     * @param _amount Amount of tokens to claim
     * @param _merkleProof Merkle proof to validate the claim
     */
    function claim(uint256 _amount, bytes32[] calldata _merkleProof) external {
        if (hasClaimed[msg.sender]) revert AlreadyClaimed();
        if (_amount == 0) revert AmountIsZero();

        // Verify the Merkle proof
        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(msg.sender, _amount))));

        if (!MerkleProof.verify(_merkleProof, merkleRoot, leaf)) revert InvalidMerkleProof();

        hasClaimed[msg.sender] = true;

        // Transfer tokens to the claimant
        token.transferFrom(treasury, msg.sender, _amount);

        emit TokensClaimed(msg.sender, _amount);
    }

    function withdraw(address _to, IERC20 _asset) external onlyOwner {
        uint256 balance = _asset.balanceOf(address(this));
        if (balance == 0) revert ZeroBalanceToken(address(_asset));

        _asset.safeTransfer(_to, balance);
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
     //////////////////////////////////////////////////////////////*/

    function _setMerkleRoot(bytes32 _merkleRoot) private {
        if (_merkleRoot == bytes32(0)) revert EmptyMerkleRoot();

        emit MerkleRootUpdated(merkleRoot, _merkleRoot);

        merkleRoot = _merkleRoot;
    }
}
