// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "../../src/paymasters/SponsorPaymaster.sol";
import "@kinto-core-script/utils/MigrationHelper.sol";

contract KintoMigration26DeployScript is MigrationHelper {
    using ECDSAUpgradeable for bytes32;

    function run() public override {
        super.run();

        bytes memory bytecode =
            abi.encodePacked(type(SponsorPaymaster).creationCode, abi.encode(_getChainDeployment("EntryPoint")));
        _deployImplementationAndUpgrade("SponsorPaymaster", "V7", bytecode);
    }
}
