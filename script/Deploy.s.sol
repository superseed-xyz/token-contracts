// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28 <0.9.0;

import { BaseScript } from "./Base.s.sol";
import { SuperseedToken } from "../src/token/SuperseedToken.sol";
import { TokenClaim } from "../src/claim/TokenClaim.sol";

/// @dev See the Solidity Scripting tutorial: https://book.getfoundry.sh/tutorials/solidity-scripting
contract Deploy is BaseScript {
    /*
     * todo: These are mock addresses for the purpose of this example
     *       In a real-world scenario, you would replace these with actual addresses
     */
    address public superAdmin = makeAddr("Super Admin");
    address public claimOwner = makeAddr("Claim Owner");
    address public minter = makeAddr("Minter");
    address public treasury = makeAddr("Treasury");

    function run() public broadcast returns (SuperseedToken token, TokenClaim claim) {
        token = new SuperseedToken(superAdmin, minter, treasury);
        claim = new TokenClaim(claimOwner, address(token), treasury);
        // set merkle root on TokenClaim contract

    }
}
