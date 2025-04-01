# Superchain Onion Calls

A framework for semi-atomic cross-chain operations across Optimism's superchain ecosystem with conditional execution paths.

![Onion Calls Concept](https://i.imgur.com/example-placeholder.png)

## Overview

The Superchain Onion Calls system enables complex, multi-chain workflows by allowing developers to create "onion-style" call structures where each layer can conditionally trigger the next based on success or failure.

Key features:
- **Cross-chain execution** between any OP chains (Optimism, Base, Zora, etc.)
- **Conditional branching** with success and failure paths
- **Nested call structures** for complex, multi-step workflows
- **No token bridging required** - uses Optimism's native L2-to-L2 messaging

Built on Optimism's upcoming interop solution, this system enables previously impossible cross-chain workflows with minimal coordination overhead.

## How It Works

The system conceptualizes cross-chain operations as "onion layers" - each call can contain two nested calls (success and failure branches) that execute conditionally based on the outcome of the parent call:

1. **Initiation**: User triggers a cross-chain call via the `execute()` function
2. **Message Passing**: The call is sent to the target chain via Optimism's L2ToL2CrossDomainMessenger
3. **Execution**: On the destination chain, the primary call executes
4. **Conditional Branching**:
   - If successful → execute the onSuccess branch (which may target any chain)
   - If failed → execute the onFailure branch (which may target any chain)
5. **Recursive Execution**: Each branch can contain further nested calls, creating a chain of operations

## Key Components

### CrossChainCall Structure

```solidity
struct CrossChainCall {
    uint256 destinationChain; // Chain ID where this call executes
    address target;           // Contract address to call
    bytes callData;           // Data to pass to the target
    bytes onSuccessData;      // Optional encoded CrossChainCall for success path
    bytes onFailureData;      // Optional encoded CrossChainCall for failure path
}
```

### CrossChainExecutor Contract

The universal executor contract deployed on each chain. It:
- Initiates cross-chain operations via `execute()`
- Processes incoming messages via `handleMessage()`
- Handles conditional branching based on call outcomes

### L2ToL2CrossDomainMessenger

The system leverages Optimism's native L2-to-L2 messaging predeploy at `0x4200000000000000000000000000000000000023` on all OP chains.

## Installation

```bash
# Clone the repository
git clone https://github.com/yourusername/superchain-onion-calls.git
cd superchain-onion-calls

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

### Basic Cross-Chain Call

```solidity
// Define a cross-chain call from Optimism to Base
CrossChainCall memory call = CrossChainCall({
    destinationChain: 8453,                                    // Base chain ID
    target: 0x1234567890123456789012345678901234567890,       // Target on Base
    callData: abi.encodeWithSelector(bytes4(keccak256("transfer(address,uint256)")), recipient, amount),
    onSuccessData: bytes(""),                                  // No success branch
    onFailureData: bytes("")                                   // No failure branch
});

// Execute the call
crossChainExecutor.execute(call, 8453);
```

### Multi-Chain Workflow with Conditional Branching

```solidity
// Define a fallback call to execute on Zora if the main call fails
CrossChainCall memory failureCall = CrossChainCall({
    destinationChain: 999,                                    // Zora chain ID
    target: 0xAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA,       // Fallback target
    callData: abi.encodeWithSelector(bytes4(keccak256("logFailure(string)")), "Main operation failed"),
    onSuccessData: bytes(""),
    onFailureData: bytes("")
});

// Define a follow-up call to execute on Optimism if the main call succeeds
CrossChainCall memory successCall = CrossChainCall({
    destinationChain: 10,                                     // Optimism chain ID
    target: 0xBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB,       // Success target
    callData: abi.encodeWithSelector(bytes4(keccak256("finalizeOperation(uint256)")), operationId),
    onSuccessData: bytes(""),
    onFailureData: bytes("")
});

// Define the main call to execute on Base with nested branches
CrossChainCall memory mainCall = CrossChainCall({
    destinationChain: 8453,                                   // Base chain ID
    target: 0xCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC,       // Main target
    callData: abi.encodeWithSelector(bytes4(keccak256("processOperation(uint256)")), operationId),
    onSuccessData: abi.encode(successCall),                   // On success → Optimism
    onFailureData: abi.encode(failureCall)                    // On failure → Zora
});

// Start the workflow from any chain
crossChainExecutor.execute(mainCall, 8453);
```

## Security Considerations

- **Semi-Atomicity**: While each chain's execution is atomic, the entire cross-chain process is not fully atomic. Design workflows with this in mind.
- **Authentication**: Only the L2ToL2CrossDomainMessenger can invoke `handleMessage()`, preventing unauthorized calls.
- **Chain Validation**: Messages are validated to ensure they're executed on the correct chain.
- **Nested Call Failure**: Local execution failures in nested calls revert with the `CallFailed` error.

## Limitations

- **OP Chain Only**: Only works within the Optimism superchain ecosystem (Optimism, Base, Zora, etc.)
- **Message Reliability**: Depends on Optimism's interop messaging system and relayer network
- **Response Latency**: Cross-chain operations are subject to finality periods and may take several minutes to complete

## License

MIT