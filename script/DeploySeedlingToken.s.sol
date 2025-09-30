// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28 <0.9.0;

import { console, Script } from "forge-std/src/Script.sol";

import { CharacterToken } from "../src/character/CharacterToken.sol";
import { CharacterMinter } from "src/character/CharacterMinter.sol";

contract Deploy is Script {
    function run() public {
        // CharacterToken -> owner_ -> SEEDLINGS_ADMIN
        // SEEDLINGS_SERVER_SIGNER
        address admin = vm.envAddress("SEEDLINGS_ADMIN");
        address serverSigner = vm.envAddress("SEEDLINGS_SERVER_SIGNER");
        vm.startBroadcast();

        CharacterToken tokenContract = new CharacterToken("Seedlings", "LINGS");
        CharacterMinter minterContract = new CharacterMinter(address(tokenContract), admin, serverSigner);

        // Grant minter role to CharacterMinter and remove it from admin
        tokenContract.setupRoles(admin, address(minterContract));

        vm.stopBroadcast();

        console.log("Token:", address(tokenContract));
        console.log("CharacterMinter:", address(minterContract));
    }
}
