// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/CrossChainExecutor.sol";

/// @title CrossChainExecutorScript
/// @notice Deployment script for the CrossChainExecutor contract
/// @dev Uses Foundry's Script functionality to deploy the CrossChainExecutor
///      The contract automatically uses the standard L2ToL2CrossDomainMessenger
///      address (0x4200000000000000000000000000000000000023) on OP chains
contract CrossChainExecutorScript is Script {
    bytes32 salt = keccak256("executor");

    /// @notice Deploys a new instance of the CrossChainExecutor contract
    /// @dev No constructor parameters needed as the messenger address is hardcoded
    ///      via the Predeploys library in the CrossChainCallLibrary
    function run() external {
        vm.startBroadcast();

        // Deploy the CrossChainExecutor
        new CrossChainExecutor{salt: salt}();

        vm.stopBroadcast();
    }
}
