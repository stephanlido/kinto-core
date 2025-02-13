// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "../../src/inflators/KintoInflator.sol";
import "@kinto-core-script/utils/MigrationHelper.sol";

contract KintoMigration44DeployScript is MigrationHelper {
    using ECDSAUpgradeable for bytes32;

    function run() public override {
        super.run();

        bytes memory bytecode = abi.encodePacked(type(KintoInflator).creationCode);
        _deployImplementationAndUpgrade("KintoInflator", "V2", bytecode);
    }
}
