// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28 <0.9.0;

import { console, Script } from "forge-std/src/Script.sol";

import { CharacterToken } from "../src/character/CharacterToken.sol";
import { CharacterMinter } from "src/character/CharacterMinter.sol";

contract Deploy is Script {
    function run() public {
        address admin = vm.envAddress("ADMIN_ADDRESS");
        address serverSigner = vm.envAddress("SERVER_SIGNER");
        vm.startBroadcast();

		CharacterToken token = new CharacterToken("Seedlings", "SEED", admin, admin);
		CharacterMinter cm = new CharacterMinter(address(token), admin, serverSigner);

		// Grant minter role to CharacterMinter and remove it from admin
		token.grantRole(token.MINTER_ROLE(), address(cm));
		token.revokeRole(token.MINTER_ROLE(), admin);

        vm.stopBroadcast();

        console.log("Token:", address(token));
        console.log("CharacterMinter:", address(cm));
    }
}
