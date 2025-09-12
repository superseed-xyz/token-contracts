// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28 <0.9.0;

import { console, Script } from "forge-std/src/Script.sol";

import { CharacterToken } from "../src/token/CharacterToken.sol";
import { CharacterClaim } from "../src/claim/CharacterClaim.sol";

contract Deploy is Script {
    function run() public {
        address admin = vm.envAddress("ADMIN_ADDRESS");

        vm.startBroadcast();

        CharacterToken token = new CharacterToken("Seedlings", "SEED", admin);
        CharacterClaim claim = new CharacterClaim(address(token), admin);

        if (token.hasRole(token.getRoleAdmin(token.MINTER_ROLE()), address(this))) {
            token.grantRole(token.MINTER_ROLE(), address(claim));
        } else {
            console.log(
                "WARNING: Deployer does not have admin role for MINTER_ROLE. Skipping grantRole. Please ensure the admin grants MINTER_ROLE to the claim contract."
            );
        }

        vm.stopBroadcast();

        console.log("Token:", address(token));
        console.log("Claim:", address(claim));
    }
}
