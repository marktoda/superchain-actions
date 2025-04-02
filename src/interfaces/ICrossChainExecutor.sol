// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title CrossChainCall
/// @notice A data structure representing a cross-chain call with nested conditional branches
/// @dev This structure forms the foundation of the action pattern, where each call
///      can contain two conditional branches that execute based on the success or failure
///      of the primary call.
struct CrossChainCall {
    /// @notice Chain ID where the call should be executed
    /// @dev Must match the block.chainid where this call is being processed
    uint256 destinationChain;
    /// @notice Target contract address to call on the destination chain
    address target;
    /// @notice Calldata to pass to the target contract
    bytes callData;
    /// @notice Optional encoded CrossChainCall to execute if the primary call succeeds
    /// @dev Empty bytes indicates no onSuccess branch
    ///      Non-empty bytes must be an abi.encoded CrossChainCall struct
    bytes onSuccessData;
    /// @notice Optional encoded CrossChainCall to execute if the primary call fails
    /// @dev Empty bytes indicates no onFailure branch
    ///      Non-empty bytes must be an abi.encoded CrossChainCall struct
    bytes onFailureData;
    /// @notice The original sender who initiated the first cross-chain call
    /// @dev This address is preserved across chain hops to maintain sender identity
    address initiator;
}

/// @title ICrossChainExecutor
/// @notice Interface for the universal executor that processes cross-chain call payloads
/// @dev This interface defines the core functionality for initiating and handling
///      cross-chain calls in the Superchain Actions system
interface ICrossChainExecutor {
    /// @notice Initiates a cross-chain call to the specified destination chain
    /// @param call The cross-chain call to execute
    function execute(CrossChainCall calldata call) external;

    /// @notice Processes an incoming cross-chain message
    /// @dev Should only be callable by the authorized cross-chain messenger
    /// @param call The cross-chain call to process on this chain
    function handleMessage(CrossChainCall calldata call) external;
}
