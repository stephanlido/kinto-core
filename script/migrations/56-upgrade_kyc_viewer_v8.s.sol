// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "../../src/viewers/KYCViewer.sol";
import "@kinto-core-script/utils/MigrationHelper.sol";

contract KintoMigration56DeployScript is MigrationHelper {
    using ECDSAUpgradeable for bytes32;

    function run() public override {
        super.run();

        // generate bytecode for KYCViewer
        bytes memory bytecode = abi.encodePacked(
            type(KYCViewerV8).creationCode,
            abi.encode(
                _getChainDeployment("KintoWalletFactory"),
                _getChainDeployment("Faucet"),
                _getChainDeployment("EngenCredits")
            )
        );

        // upgrade KYCViewer to V8
        _deployImplementationAndUpgrade("KYCViewer", "V8", bytecode);
    }
}
