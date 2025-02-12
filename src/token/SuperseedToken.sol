// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity 0.8.28;

import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { ERC20Burnable } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import { ERC20Permit } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import { ERC20Votes } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import { Nonces } from "@openzeppelin/contracts/utils/Nonces.sol";

/**
 * @custom:security-contact security@superseed.xyz
 * @title Superseed Token
 * @notice The SuperseedToken.sol token used in governance and supporting voting and delegation.
 *         Implements EIP 2612 allowing signed approvals.
 *         A `MintManager` instance has permission to the `mint` function only, for the purposes of enforcing the token
 *         inflation schedule.
 */
contract SuperseedToken is ERC20, ERC20Burnable, AccessControl, ERC20Permit, ERC20Votes {
    /*//////////////////////////////////////////////////////////////////////////
                                  CONTRACT STATE
    //////////////////////////////////////////////////////////////////////////*/

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    /*//////////////////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    //////////////////////////////////////////////////////////////////////////*/

    constructor(
        address superAdmin,
        address minter,
        address treasury
    )
        ERC20("Superseed", "SUPR")
        ERC20Permit("Superseed")
    {
        _mint(treasury, 10_000_000_000e18);

        _grantRole(DEFAULT_ADMIN_ROLE, superAdmin);
        _grantRole(MINTER_ROLE, minter);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                   PUBLIC INTERFACE
    //////////////////////////////////////////////////////////////////////////*/

    /**
     * @dev Mints `amount` tokens to the `to` address.
     *      Can only be called by an account with the `MINTER_ROLE`.
     * @param to The address to mint tokens to.
     * @param amount The amount of tokens to mint.
     */
    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                REQUIRED OVERRIDES
    //////////////////////////////////////////////////////////////////////////*/

    function _update(address from, address to, uint256 value) internal override(ERC20, ERC20Votes) {
        super._update(from, to, value);
    }

    function nonces(address owner) public view override(ERC20Permit, Nonces) returns (uint256) {
        return super.nonces(owner);
    }
}
