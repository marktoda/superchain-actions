// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {L2ToL2CrossDomainMessenger} from "optimism/packages/contracts-bedrock/src/L2/L2ToL2CrossDomainMessenger.sol";
import {Predeploys} from "optimism/packages/contracts-bedrock/src/libraries/Predeploys.sol";
import {CrossChainCall, ICrossChainExecutor} from "../interfaces/ICrossChainExecutor.sol";

/// @title CrossChainCallLibrary
/// @notice Library containing utilities for processing cross-chain calls
/// @dev This library handles the conditional branching logic and cross-chain
///      message dispatching for the Superchain Actions system
library CrossChainCallLibrary {
    /// @notice Reference to the L2ToL2CrossDomainMessenger predeploy
    /// @dev Uses Optimism's Predeploys library to reference the standard address
    ///      (0x4200000000000000000000000000000023)
    L2ToL2CrossDomainMessenger public constant MESSENGER =
        L2ToL2CrossDomainMessenger(Predeploys.L2_TO_L2_CROSS_DOMAIN_MESSENGER);

    /// @notice Emitted when a nested call is dispatched
    /// @param destinationChain The chain ID where the call is sent to
    /// @param target The target address for the call
    /// @param local Whether the call was executed locally (true) or dispatched cross-chain (false)
    event NestedCallDispatched(uint256 destinationChain, address target, bool local);

    /// @notice Thrown when a nested local call fails
    /// @dev This error is raised when a locally executed call returns false
    error CallFailed();

    /// @notice Processes the onSuccess branch of a CrossChainCall
    /// @dev If onSuccessData is empty, this function does nothing
    ///      If onSuccessData contains an encoded CrossChainCall, it is processed
    /// @param call The parent CrossChainCall containing the onSuccess branch
    function onSuccess(CrossChainCall calldata call) internal {
        if (call.onSuccessData.length == 0) {
            // No onSuccess branch, nothing to do.
            return;
        }

        CrossChainCall memory nextCall = abi.decode(call.onSuccessData, (CrossChainCall));
        // ensure the next initiator is propagated down
        nextCall.initiator = call.initiator;
        CrossChainCallLibrary.doCall(nextCall);
    }

    /// @notice Processes the onFailure branch of a CrossChainCall
    /// @dev If onFailureData is empty, this function does nothing
    ///      If onFailureData contains an encoded CrossChainCall, it is processed
    /// @param call The parent CrossChainCall containing the onFailure branch
    function onFailure(CrossChainCall memory call) internal {
        if (call.onFailureData.length == 0) {
            // No onFailure branch, nothing to do.
            return;
        }

        CrossChainCall memory nextCall = abi.decode(call.onFailureData, (CrossChainCall));
        // ensure the next initiator is propagated down
        nextCall.initiator = call.initiator;
        CrossChainCallLibrary.doCall(nextCall);
    }

    /// @notice Executes a CrossChainCall, either locally or by sending it to another chain
    /// @dev If the destination chain matches the current chain, executes locally
    ///      Otherwise, sends the call to the destination chain via the messenger
    /// @param call The CrossChainCall to execute
    function doCall(CrossChainCall memory call) internal {
        if (call.destinationChain == block.chainid) {
            // Local execution on current chain
            (bool success,) = call.target.call(call.callData);
            if (!success) revert CallFailed();
        } else {
            // Cross-chain execution via messenger
            MESSENGER.sendMessage(
                call.destinationChain,
                address(this),
                abi.encodeWithSelector(ICrossChainExecutor.handleMessage.selector, call)
            );
        }
        emit NestedCallDispatched(call.destinationChain, call.target, call.destinationChain == block.chainid);
    }
}
