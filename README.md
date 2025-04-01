# Superchain Actions

A framework for semi-atomic cross-chain operations across Optimism's superchain ecosystem with conditional execution paths.

## Overview

The Superchain Actions system enables complex, multi-chain workflows by allowing developers to create nested call structures where each action can conditionally trigger the next based on success or failure.

Key features:

- **Cross-chain execution** between any OP chains (Optimism, Base, Zora, etc.)
- **Conditional branching** with success and failure paths
- **Nested action structures** for complex, multi-step workflows
- **No token bridging required** - uses Optimism's native L2-to-L2 messaging

Built on Optimism's upcoming interop solution, this system enables previously impossible cross-chain workflows with minimal coordination overhead.

## How It Works

The system conceptualizes cross-chain operations as nested actions - each call can contain two nested calls (success and failure branches) that execute conditionally based on the outcome of the parent call:

1. **Initiation**: User triggers a cross-chain action via the `execute()` function
2. **Message Passing**: The action is sent to the target chain via Optimism's L2ToL2CrossDomainMessenger
3. **Execution**: On the destination chain, the primary call executes
4. **Conditional Branching**:
   - If successful → execute the onSuccess branch (which may target any chain)
   - If failed → execute the onFailure branch (which may target any chain)
5. **Recursive Execution**: Each branch can contain further nested actions, creating a chain of operations

## Key Components

### CrossChainCall Structure

```solidity
struct CrossChainCall {
    uint256 destinationChain; // Chain ID where this action executes
    address target;           // Contract address to call
    bytes callData;           // Data to pass to the target
    bytes onSuccessData;      // Optional encoded CrossChainCall for success path
    bytes onFailureData;      // Optional encoded CrossChainCall for failure path
}
```

### CrossChainExecutor Contract

The universal executor contract deployed on each chain. It:

- Initiates cross-chain actions via `execute()`
- Processes incoming messages via `handleMessage()`
- Handles conditional branching based on action outcomes

### L2ToL2CrossDomainMessenger

The system leverages Optimism's native L2-to-L2 messaging predeploy at `0x4200000000000000000000000000000000000023` on all OP chains.

## Installation

```bash
# Clone the repository
git clone https://github.com/yourusername/superchain-actions.git
cd superchain-actions

# Install dependencies
forge install
```

## Building

```bash
forge build
```

## Testing

```bash
forge test
```

## Deployment

Deploy to any OP chain (Base, Optimism, Zora, etc.):

```bash
forge script script/CrossChainExecutor.s.sol:CrossChainExecutorScript \
  --rpc-url <your_rpc_url> \
  --private-key <your_private_key> \
  --broadcast
```

No constructor parameters are needed as the system automatically uses the standard L2ToL2CrossDomainMessenger predeploy address.

## Usage Examples

### Basic Cross-Chain Action

```solidity
// Define a cross-chain action from Optimism to Base
CrossChainCall memory action = CrossChainCall({
    destinationChain: 8453,                                    // Base chain ID
    target: 0x1234567890123456789012345678901234567890,       // Target on Base
    callData: abi.encodeWithSelector(bytes4(keccak256("transfer(address,uint256)")), recipient, amount),
    onSuccessData: bytes(""),                                  // No success branch
    onFailureData: bytes("")                                   // No failure branch
});

// Execute the action
crossChainExecutor.execute(action, 8453);
```

### Multi-Chain Workflow with Conditional Branching

```solidity
// Define a fallback action to execute on Zora if the main action fails
CrossChainCall memory failureAction = CrossChainCall({
    destinationChain: 999,                                    // Zora chain ID
    target: 0xAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA,       // Fallback target
    callData: abi.encodeWithSelector(bytes4(keccak256("logFailure(string)")), "Main operation failed"),
    onSuccessData: bytes(""),
    onFailureData: bytes("")
});

// Define a follow-up action to execute on Optimism if the main action succeeds
CrossChainCall memory successAction = CrossChainCall({
    destinationChain: 10,                                     // Optimism chain ID
    target: 0xBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB,       // Success target
    callData: abi.encodeWithSelector(bytes4(keccak256("finalizeOperation(uint256)")), operationId),
    onSuccessData: bytes(""),
    onFailureData: bytes("")
});

// Define the main action to execute on Base with nested branches
CrossChainCall memory mainAction = CrossChainCall({
    destinationChain: 8453,                                   // Base chain ID
    target: 0xCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC,       // Main target
    callData: abi.encodeWithSelector(bytes4(keccak256("processOperation(uint256)")), operationId),
    onSuccessData: abi.encode(successAction),                 // On success → Optimism
    onFailureData: abi.encode(failureAction)                  // On failure → Zora
});

// Start the workflow from any chain
crossChainExecutor.execute(mainAction, 8453);
```

## Security Considerations

- **Semi-Atomicity**: While each chain's execution is atomic, the entire cross-chain process is not fully atomic. Design workflows with this in mind.
- **Authentication**: Only the L2ToL2CrossDomainMessenger can invoke `handleMessage()`, preventing unauthorized calls.
- **Chain Validation**: Messages are validated to ensure they're executed on the correct chain.
- **Nested Action Failure**: Local execution failures in nested actions revert with the `CallFailed` error.

## Limitations

- **OP Chain Only**: Only works within the Optimism superchain ecosystem (Optimism, Base, Zora, etc.)
- **Message Reliability**: Depends on Optimism's interop messaging system and relayer network
- **Response Latency**: Cross-chain operations are subject to finality periods and may take several minutes to complete

## License

MIT

