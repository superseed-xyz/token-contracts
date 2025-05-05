// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28 <0.9.0;

import { console, Script } from "forge-std/src/Script.sol";

import { BaseDeployerScript } from "./BaseDeployer.s.sol";
import { MintManager } from "../src/token/MintManager.sol";
import { SuperseedToken } from "../src/token/SuperseedToken.sol";
import { TokenClaim } from "../src/claim/TokenClaim.sol";

contract DeployStaging is Script {

    struct ClaimParams {
        address owner;
        address treasury;
    }

    struct Treasuries {
        address privateInvestors;
        address superSale;
        address ecosystemFund;
        address foundationTreasury;
        address networkParticipationRewards;
        address contributors;
    }


    ClaimParams public claimParams;
    Treasuries public treasuries;

    // ================== CONSTANTS ==================

    // Claim Constants
    bytes32 public constant CLAIM_MERKLE_ROOT = 0xe99e5bfc8187caa2cdfdda7ddfcb6ab5f310028ebf827f8e7a355d00154ff9b9;

    function setUp() public {
        // ==================== TREASURIES ====================
        treasuries = Treasuries(
            0x1E4E5e9D0Bb6E0F9F65e9dE460303D7CC8bF639f,
            0x8F522A44157aD7F7D522C48a7F67Dd2413fAbbc8,
            0xF9943Ac07C296fF3D6C90aB5866B151bb887D3bf,
            0xeFb651a2934C7Dd1EA398eb4cCa5e494f44ABcAa,
            0x0b750e026F4a04EF6cD334fC2669605b76e4B747,
            0xc8254f3e7fF702a3Df7d67B204b7f96Aa5E6818F
        );

        claimParams = ClaimParams(0x6418A646Ed5D55D41d9aD8d0B662bEb8db84e995, treasuries.superSale);
    }

    function run() public returns (SuperseedToken token, TokenClaim claim) {
        console.log("broadcaster: %s", msg.sender);

        vm.startBroadcast();

        // Instantiate SuperseedToken
        token = SuperseedToken(0xC61887A23f29A61C938dbB8651f6c52070ef67ee);

        // Deploy TokenClaim
        claim = new TokenClaim(claimParams.owner, address(token), claimParams.treasury, CLAIM_MERKLE_ROOT);

        vm.stopBroadcast();
    }
}
