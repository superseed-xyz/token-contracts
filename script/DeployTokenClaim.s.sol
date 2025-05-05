// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28 <0.9.0;

import { console, Script } from "forge-std/src/Script.sol";

import { BaseDeployerScript } from "./BaseDeployer.s.sol";
import { MintManager } from "../src/token/MintManager.sol";
import { SuperseedToken } from "../src/token/SuperseedToken.sol";
import { TokenClaim } from "../src/claim/TokenClaim.sol";

contract DeployStaging is Script {
    // Claim Constants
    bytes32 public constant CLAIM_MERKLE_ROOT = 0xe99e5bfc8187caa2cdfdda7ddfcb6ab5f310028ebf827f8e7a355d00154ff9b9;

    function run() public returns (SuperseedToken token, TokenClaim claim) {
        console.log("broadcaster: %s", msg.sender);

        vm.startBroadcast();

        // Instantiate SuperseedToken
        token = SuperseedToken(0xC61887A23f29A61C938dbB8651f6c52070ef67ee);

        // Deploy TokenClaim
        claim = new TokenClaim(
            0xFf23CF95Cec5339d4bc3EA9fad4c5eEb585ae2e4,
            address(token),
            0xFf23CF95Cec5339d4bc3EA9fad4c5eEb585ae2e4,
            CLAIM_MERKLE_ROOT
        );

        token.approve(address(claim), type(uint256).max);

        vm.stopBroadcast();
    }
}
