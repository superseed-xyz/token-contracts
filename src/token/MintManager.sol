// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/**
 * @title Superseed MintManager
 * @notice This is a temporary contract.
 *         In the context of controlled token inflation, this makes the most sense because we have enough flexibility
 *         to upgrade the mint manager on the token contract when needed, and these actions will be managed by a DAO eventually.
 *         It's the only address having access to the mint function on the token.
 *         Minting is currently disabled.
 */
contract MintManager {
    /**
     * @dev This function is disabled in this temporary contract.
     */
    function mint(address, uint256) pure external {
        revert("Minting is disabled");
    }
}
