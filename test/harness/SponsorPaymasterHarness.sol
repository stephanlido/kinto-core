// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "../../src/interfaces/IKintoEntryPoint.sol";
import "../../src/interfaces/IKintoID.sol";
import "../../src/interfaces/IKintoAppRegistry.sol";

import {SponsorPaymaster} from "../../src/paymasters/SponsorPaymaster.sol";

// Harness contract to expose internal functions for testing.
contract SponsorPaymasterHarness is SponsorPaymaster {
    constructor(IEntryPoint __entryPoint) SponsorPaymaster(__entryPoint) {
        // body intentionally blank
    }

    function exposed_validatePaymasterUserOp(UserOperation calldata userOp, bytes32 userOpHash, uint256 maxCost)
        public
        view
        returns (bytes memory context, uint256 validationData)
    {
        return _validatePaymasterUserOp(userOp, userOpHash, maxCost);
    }
}
