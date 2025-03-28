// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28 <0.9.0;

import { Script } from "forge-std/src/Script.sol";

abstract contract BaseDeployerScript is Script {
    enum Environment {
        Staging,
        Production
    }

    /// @dev The privateKey of the transaction broadcaster.
    uint256 internal privateKey;

    /// @dev The address of the transaction broadcaster.
    address internal broadcaster;

    /// @dev Initializes the transaction broadcaster like this:
    ///
    /// - If $ETH_FROM is defined, use it.
    /// - Otherwise, derive the broadcaster address from $MNEMONIC.
    /// - If $MNEMONIC is not defined, default to a test mnemonic.
    ///
    /// The use case for $ETH_FROM is to specify the broadcaster key and its address via the command line.
    constructor(Environment environment) {
        if (environment == Environment.Staging) {
            privateKey = vm.envUint("PRIVATE_KEY_STAGING");
        } else {
            privateKey = vm.envUint("PRIVATE_KEY_PROD");
        }

        require(privateKey != 0, "BaseDeployerScript: private key not set");
        broadcaster = vm.rememberKey(privateKey);
    }

    modifier broadcast() {
        vm.startBroadcast(privateKey);
        _;
        vm.stopBroadcast();
    }
}
