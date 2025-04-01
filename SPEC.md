# Superchain Onion Calls

## 1. Overview

This design enables semi-atomic, multi-chain batches on the OP superchain using Optimism’s upcoming interop solution. The key idea is to allow users to “wrap” a series of actions—like layers of an onion—in which each layer represents a full call that can execute on any chain. Depending on whether a call succeeds or fails, the corresponding next “layer” (which is itself a complete call with destination chain, target, and calldata) is triggered. This design leverages:

- **OP interop’s “pull” mechanism:** The origin chain emits an event, and destination chains pick it up.
- **L2ToL2Messenger abstraction:** This sends messages that include a destination chain, target address, and calldata.
- **Auto-relayer:** An opt-in system that automatically relays messages.
- **7702 smart contract wallets:** Allowing calls to simulate execution as if coming directly from the user.

---

## 2. Core Components

### Universal Executor Contract

Deployed on each chain, this contract provides:

- **An entry point (e.g. `executeBatch`)** that starts the onion chain by sending the first cross-chain message.
- **A message handler (`handleMessage`)** that is triggered when an L2ToL2Messenger event is picked up on a destination chain.

### L2ToL2Messenger Interface

This interface abstracts away the details of cross-chain messaging. Its `sendMessage` method emits an event carrying:

- `destinationChain`
- `target` address (typically the executor on the target chain)
- `calldata` (encoding the full cross-chain call structure)

### 7702 Smart Contract Wallets

These wallets allow the executor to simulate a cross-chain call on behalf of a user, preserving the user’s context and permissions.

---

## 3. Data Format

The core data structure is the **CrossChainCall**. In our design, each call includes:

- **Destination details:** The chain on which the call should be executed.
- **Target contract and calldata:** The actual action to be executed.
- **Nested fallback branches:**
  - **onSuccess:** A full call (destination, target, calldata) to execute if the primary call succeeds.
  - **onFailure:** A full call (destination, target, calldata) to execute if the primary call fails.

Each of these nested calls can itself be another CrossChainCall, allowing you to “wrap” multiple layers (or an onion chain) of cross-chain actions. In effect, the entire batch is a nested structure where a single call can lead to a series of further calls across chains.

---

## 4. Execution Flow

1. **Initiation (Origin Chain):**
   - The user calls `executeBatch` on the Universal Executor, supplying an initial `CrossChainCall` that represents the first layer of the onion.
   - The Executor uses the L2ToL2Messenger to send the call as a message (event) to the designated destination chain.
2. **Message Relay:**
   - An auto-relayer (if opted in) picks up the event and submits it to the destination chain.
3. **Message Handling (Destination Chain):**
   - The Executor’s `handleMessage` function is invoked by the messenger.
   - It decodes the payload into a `CrossChainCall` structure.
   - The Executor then executes the call locally (using a low-level call or by invoking a 7702 wallet).
   - Based on the outcome:
     - **On Success:** If the primary call succeeds and an `onSuccess` call is specified, the executor dispatches this next layer (which itself can be a full cross-chain call with further nested calls).
     - **On Failure:** If the call fails and an `onFailure` call is provided, that branch is dispatched.
   - This mechanism creates an “onion” where each layer (or call) may lead to another, forming a chain of actions across multiple chains.
4. **Continuation:**
   - The new message is relayed to its target chain, and the process repeats until no further nested calls remain.

---

## 5. Code Example

Below is a simplified Solidity example that demonstrates the key parts of this design:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title L2ToL2Messenger Interface
/// @notice A simplified interface representing the cross-chain messenger.
interface IL2ToL2Messenger {
    function sendMessage(
        uint256 destinationChain,
        address target,
        bytes calldata data
    ) external;
}

/// @title CrossChainExecutor
/// @notice A universal executor that processes onion-style cross-chain call payloads.
/// Each call includes nested onSuccess and onFailure branches that can themselves
/// be full cross-chain calls or local actions.
contract CrossChainExecutor {
    IL2ToL2Messenger public messenger;

    /// @notice A structure representing a cross-chain call with nested actions.
    struct CrossChainCall {
        uint256 destinationChain; // Chain ID where the call should be executed.
        address target;           // Target contract address.
        bytes callData;           // Calldata for the primary action.

        // Encoded nested calls (onSuccess and onFailure branches).
        // These are full calls and can be cross-chain or local.
        bytes onSuccessData;
        bytes onFailureData;
    }

    /// @notice Only allows calls from the authorized messenger.
    modifier onlyMessenger() {
        require(msg.sender == address(messenger), "Not authorized");
        _;
    }

    /// @notice Initiates the cross-chain batch execution.
    /// @param callChain The top-level cross-chain call (first onion layer).
    function executeBatch(CrossChainCall calldata callChain) external {
        messenger.sendMessage(
            callChain.destinationChain,
            address(this),               // Target: our executor on the destination chain.
            abi.encode(callChain)        // Encode the entire call chain.
        );
    }

    /// @notice Processes incoming cross-chain messages.
    /// Decodes the payload, executes the primary call, and dispatches the next layer.
    /// @param data The encoded CrossChainCall payload.
    function handleMessage(bytes calldata data) external onlyMessenger {
        CrossChainCall memory cCall = abi.decode(data, (CrossChainCall));

        // Execute the primary action.
        bool success = _executeCall(cCall.target, cCall.callData);

        // Dispatch the next onion layer based on the outcome.
        if (success && cCall.onSuccessData.length > 0) {
            // If onSuccess branch exists, decode and send the next call.
            messenger.sendMessage(
                abi.decode(cCall.onSuccessData, (CrossChainCall)).destinationChain,
                address(this),
                cCall.onSuccessData
            );
        } else if (!success && cCall.onFailureData.length > 0) {
            // If onFailure branch exists, decode and send the fallback call.
            messenger.sendMessage(
                abi.decode(cCall.onFailureData, (CrossChainCall)).destinationChain,
                address(this),
                cCall.onFailureData
            );
        }
        // If no nested call is provided, the process ends.
    }

    /// @notice Helper function to execute a call.
    /// @param target The contract to be called.
    /// @param data The calldata for the function call.
    /// @return success True if the call succeeded, false otherwise.
    function _executeCall(address target, bytes memory data) internal returns (bool) {
        (bool success, ) = target.call(data);
        return success;
    }
}

```

## 6. Considerations

- **Semi-Atomicity:**

  Each chain’s execution is atomic; however, the entire multi-chain process is not fully atomic. There may be delays between steps and possible state changes across chains. It is important to design workflows with these characteristics in mind.

- **Message Ordering & Reliability:**

  The design relies on the pull-based mechanism of the Optimism interop messenger and an auto relayer. Additional safeguards (like timeouts or manual interventions) might be necessary if messages are delayed or fail to relay.

- **Security:**
  - Ensure that only the messenger contract can call `handleMessage` (using the `onlyMessenger` modifier).
  - Validate all inputs and consider reentrancy guards, especially when interacting with external contracts or user wallets.
- **Extensibility:**

  The design can be extended to support arrays of calls per branch, more detailed error handling, and additional metadata (e.g., gas limits, fees).
