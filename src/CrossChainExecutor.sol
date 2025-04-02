// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Predeploys} from "optimism/packages/contracts-bedrock/src/libraries/Predeploys.sol";
import {L2ToL2CrossDomainMessenger} from "optimism/packages/contracts-bedrock/src/L2/L2ToL2CrossDomainMessenger.sol";
import {CrossChainCallLibrary} from "./libraries/CrossChainCallLibrary.sol";
import {CallContext} from "./libraries/CallContext.sol";
import {CrossChainCall, ICrossChainExecutor} from "./interfaces/ICrossChainExecutor.sol";

/// @title CrossChainExecutor
/// @notice A universal executor that processes cross-chain call payloads with conditional branches
/// @dev This contract serves as both the entry point for initiating cross-chain calls
///      and the handler for incoming cross-chain messages. Each chain in the Optimism
///      superchain ecosystem should have its own instance of this contract.
///      Each call includes nested onSuccess and onFailure branches that can themselves
///      be full cross-chain calls or local actions.
contract CrossChainExecutor is ICrossChainExecutor, CallContext {
    using CrossChainCallLibrary for CrossChainCall;

    /// @notice Emitted when a primary call is executed
    /// @param target The address of the contract that was called
    /// @param success Whether the call succeeded (true) or failed (false)
    event CallExecuted(address indexed target, bool success);

    /// @notice Thrown when a call is processed on the wrong chain
    /// @dev This occurs when a call's destinationChain doesn't match the current block.chainid
    error InvalidChain();

    /// @notice Thrown when a call's initiator address is not the sender of the top level execute
    error InvalidInitiator();

    /// @notice Thrown when the cross-domain sender is not authorized
    /// @dev This ensures only calls originating from this contract on other chains are processed
    error InvalidCrossDomainSender();

    /// @notice Thrown when the caller is not the L2ToL2Messenger
    error UnauthorizedSender();

    /// @notice Restricts function access to the L2ToL2CrossDomainMessenger
    /// @dev This ensures that cross-chain messages can only be processed if they
    ///      come through the official messenger contract
    modifier onlyMessenger() {
        if (msg.sender != address(CrossChainCallLibrary.MESSENGER)) revert UnauthorizedSender();
        // Ensure the message is from this contract on another chain
        (address crossDomainMessageSender,) = CrossChainCallLibrary.MESSENGER.crossDomainMessageContext();
        if (crossDomainMessageSender != address(this)) revert InvalidCrossDomainSender();

        _;
    }

    /// @notice Initiates the cross-chain batch execution
    /// @dev Sends the call to the specified destination chain via the messenger
    /// @param call The top-level cross-chain call (first action)
    function execute(CrossChainCall calldata call) external {
        if (call.initiator != msg.sender) revert InvalidInitiator();

        CrossChainCallLibrary.MESSENGER.sendMessage(
            call.destinationChain,
            address(this),
            abi.encodeWithSelector(CrossChainExecutor.handleMessage.selector, call)
        );
    }

    /// @notice Processes incoming cross-chain messages
    /// @dev Decodes the payload, verifies the chain ID, executes the primary call,
    ///      and dispatches the next call based on success or failure
    /// @param call The encoded CrossChainCall payload
    function handleMessage(CrossChainCall calldata call) external onlyMessenger {
        storeContext(call);

        // Execute the primary action
        (bool success,) = call.target.call(call.callData);
        emit CallExecuted(call.target, success);

        // Process the appropriate branch based on call outcome
        if (success) {
            call.onSuccess();
        } else {
            call.onFailure();
        }
    }
}
