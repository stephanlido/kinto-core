// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../src/wallet/KintoWallet.sol";
import "../src/wallet/KintoWalletFactory.sol";
import "../src/paymasters/SponsorPaymaster.sol";
import "../src/KintoID.sol";
import "../src/apps/KintoApp.sol";
import {UserOp} from "./helpers/UserOp.sol";
import {UUPSProxy} from "./helpers/UUPSProxy.sol";
import {AATestScaffolding} from "./helpers/AATestScaffolding.sol";
import {Create2Helper} from "./helpers/Create2Helper.sol";
import "./helpers/KYCSignature.sol";

import "@aa/interfaces/IAccount.sol";
import "@aa/interfaces/INonceManager.sol";
import "@aa/interfaces/IEntryPoint.sol";
import "@aa/core/EntryPoint.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/ECDSAUpgradeable.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {SignatureChecker} from "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import "forge-std/Test.sol";
import "forge-std/console.sol";

contract KintoAppV2 is KintoApp {
    function newFunction() external pure returns (uint256) {
        return 1;
    }

    constructor() KintoApp() {}
}

contract KintoAppTest is Create2Helper, UserOp, AATestScaffolding {
    using ECDSAUpgradeable for bytes32;
    using SignatureChecker for address;

    uint256 _chainID = 1;

    KintoAppV2 _implkintoAppV2;
    KintoAppV2 _kintoApp2;

    function setUp() public {
        vm.chainId(_chainID);
        vm.startPrank(address(1));
        _owner.transfer(1e18);
        vm.stopPrank();
        deployAAScaffolding(_owner, 1, _kycProvider, _recoverer);
    }

    function testUp() public {
        console.log("address owner", address(_owner));
        assertEq(_kintoApp.hasRole(_kintoApp.UPGRADER_ROLE(), _owner), true);
        assertEq(_kintoApp.name(), "Kinto APP");
        assertEq(_kintoApp.symbol(), "KINTOAPP");
        assertEq(_kintoApp.RATE_LIMIT_PERIOD(), 1 minutes);
        assertEq(_kintoApp.RATE_LIMIT_THRESHOLD(), 10);
        assertEq(_kintoApp.GAS_LIMIT_PERIOD(), 30 days);
        assertEq(_kintoApp.GAS_LIMIT_THRESHOLD(), 1e16);
    }

    /* ============ Upgrade Tests ============ */

    function testOwnerCanUpgradeApp() public {
        vm.startPrank(_owner);
        KintoAppV2 _implementationV2 = new KintoAppV2();
        _kintoApp.upgradeTo(address(_implementationV2));
        // re-wrap the _proxy
        _kintoApp2 = KintoAppV2(address(_kintoApp));
        assertEq(_kintoApp2.newFunction(), 1);
        vm.stopPrank();
    }

    function test_RevertWhen_OthersCannotUpgradeFactory() public {
        KintoAppV2 _implementationV2 = new KintoAppV2();
        bytes memory err = abi.encodePacked(
            "AccessControl: account ",
            Strings.toHexString(address(this)),
            " is missing role ",
            Strings.toHexString(uint256(_implementationV2.UPGRADER_ROLE()), 32)
        );
        vm.expectRevert(err);
        _kintoApp.upgradeTo(address(_implementationV2));
    }

    /* ============ App Tests & Viewers ============ */

    function testRegisterApp(string memory name, address parentContract) public {
        vm.startPrank(_user);
        assertEq(_kintoApp.appCount(), 0);
        address[] memory childContracts = new address[](1);
        childContracts[0] = address(7);
        uint256[] memory appLimits = new uint256[](4);
        appLimits[0] = _kintoApp.RATE_LIMIT_PERIOD();
        appLimits[1] = _kintoApp.RATE_LIMIT_THRESHOLD();
        appLimits[2] = _kintoApp.GAS_LIMIT_PERIOD();
        appLimits[3] = _kintoApp.GAS_LIMIT_THRESHOLD();
        _kintoApp.registerApp(
            name, parentContract, childContracts, [appLimits[0], appLimits[1], appLimits[2], appLimits[3]]
        );
        assertEq(_kintoApp.appCount(), 1);
        IKintoApp.Metadata memory metadata = _kintoApp.getAppMetadata(parentContract);
        assertEq(metadata.name, name);
        assertEq(metadata.developerWallet, address(_user));
        assertEq(metadata.dsaEnabled, false);
        assertEq(metadata.rateLimitPeriod, appLimits[0]);
        assertEq(metadata.rateLimitNumber, appLimits[1]);
        assertEq(metadata.gasLimitPeriod, appLimits[2]);
        assertEq(metadata.gasLimitCost, appLimits[3]);
        assertEq(_kintoApp.isContractSponsoredByApp(parentContract, address(7)), true);
        assertEq(_kintoApp.getContractSponsor(address(7)), parentContract);
        uint256[4] memory limits = _kintoApp.getContractLimits(address(7));
        assertEq(limits[0], appLimits[0]);
        assertEq(limits[1], appLimits[1]);
        assertEq(limits[2], appLimits[2]);
        assertEq(limits[3], appLimits[3]);
        limits = _kintoApp.getContractLimits(parentContract);
        assertEq(limits[0], appLimits[0]);
        assertEq(limits[1], appLimits[1]);
        assertEq(limits[2], appLimits[2]);
        assertEq(limits[3], appLimits[3]);
        metadata = _kintoApp.getAppMetadata(address(7));
        assertEq(metadata.name, name);
        vm.stopPrank();
    }

    function testRegisterAppAndUpdate(string memory name, address parentContract) public {
        vm.startPrank(_user);
        address[] memory childContracts = new address[](1);
        childContracts[0] = address(8);
        uint256[] memory appLimits = new uint256[](4);
        appLimits[0] = _kintoApp.RATE_LIMIT_PERIOD();
        appLimits[1] = _kintoApp.RATE_LIMIT_THRESHOLD();
        appLimits[2] = _kintoApp.GAS_LIMIT_PERIOD();
        appLimits[3] = _kintoApp.GAS_LIMIT_THRESHOLD();
        _kintoApp.registerApp(
            name, parentContract, childContracts, [appLimits[0], appLimits[1], appLimits[2], appLimits[3]]
        );
        _kintoApp.updateMetadata(
            "test2", parentContract, childContracts, [uint256(1), uint256(1), uint256(1), uint256(1)]
        );
        IKintoApp.Metadata memory metadata = _kintoApp.getAppMetadata(parentContract);
        assertEq(metadata.name, "test2");
        assertEq(metadata.developerWallet, address(_user));
        assertEq(metadata.dsaEnabled, false);
        assertEq(metadata.rateLimitPeriod, 1);
        assertEq(metadata.rateLimitNumber, 1);
        assertEq(metadata.gasLimitPeriod, 1);
        assertEq(metadata.gasLimitCost, 1);
        assertEq(_kintoApp.isContractSponsoredByApp(parentContract, address(7)), false);
        assertEq(_kintoApp.isContractSponsoredByApp(parentContract, address(8)), true);
        vm.stopPrank();
    }

    /* ============ Transfer Test ============ */

    function test_RevertWhen_TransfersAreDisabled(address parentContract) public {
        vm.startPrank(_user);
        address[] memory childContracts = new address[](1);
        childContracts[0] = address(8);
        uint256[] memory appLimits = new uint256[](4);
        appLimits[0] = _kintoApp.RATE_LIMIT_PERIOD();
        appLimits[1] = _kintoApp.RATE_LIMIT_THRESHOLD();
        appLimits[2] = _kintoApp.GAS_LIMIT_PERIOD();
        appLimits[3] = _kintoApp.GAS_LIMIT_THRESHOLD();
        _kintoApp.registerApp(
            "", parentContract, childContracts, [appLimits[0], appLimits[1], appLimits[2], appLimits[3]]
        );
        uint256 tokenIdx = _kintoApp.tokenOfOwnerByIndex(_user, 0);
        vm.expectRevert("Only mint transfers are allowed");
        _kintoApp.safeTransferFrom(_user, _user2, tokenIdx);
    }
}
