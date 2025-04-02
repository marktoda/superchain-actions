// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {CrossChainCall, ICrossChainExecutor} from "../interfaces/ICrossChainExecutor.sol";

/// @title CallContext
/// @notice Provides transient storage for cross-chain call context
/// @dev Uses EIP-1153 transient storage for efficiency
abstract contract CallContext {
    /// @notice The slot holding the initiator state transiently
    /// @dev Calculated as bytes32(uint256(keccak256("Initiator")) - 1)
    bytes32 internal constant INITIATOR_SLOT = 0xe3c5b58f602ae084d61454d01e37b118a565e2aae1e6f863300b1e06b33ad6a3;

    /// @notice Stores the initiator address in transient storage
    /// @dev Uses assembly for direct transient storage access
    /// @param call The cross-chain call containing the initiator address
    function storeContext(CrossChainCall calldata call) internal {
        address initiator = call.initiator;
        assembly ("memory-safe") {
            tstore(INITIATOR_SLOT, initiator)
        }
    }

    /// @notice Retrieves the stored initiator address from transient storage
    /// @dev Uses assembly for direct transient storage access
    /// @return initiator The address that initiated the original cross-chain call
    function getInitiator() external view returns (address initiator) {
        assembly ("memory-safe") {
            initiator := tload(INITIATOR_SLOT)
        }
    }
}
