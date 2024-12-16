// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Test } from "forge-std/Test.sol";

import { Safe } from "@safe/Safe.sol";
import { Enum } from "@safe/common/Enum.sol";
import { SafeProxy } from "@safe/proxies/SafeProxy.sol";
import { SafeProxyFactory } from "@safe/proxies/SafeProxyFactory.sol";

import { SafeSubscriptions } from "../../src/SafeSubscriptions.sol";

contract GlobalHelper is Test {
    address[] public owners;
    uint256[] public privateKeys;
    uint256 public threshold;

    SafeSubscriptions public safeSubscriptions;

    address public singleton;
    SafeProxyFactory public safeProxyFactory;
    Safe public safe;

    function setUp() public {
        (address owner, uint256 ownerPrivateKey) = makeAddrAndKey("Bob");
        owners.push(owner);
        privateKeys.push(ownerPrivateKey);
        (owner, ownerPrivateKey) = makeAddrAndKey("Alice");
        owners.push(owner);
        privateKeys.push(ownerPrivateKey);
        (owner, ownerPrivateKey) = makeAddrAndKey("Marie");
        owners.push(owner);
        privateKeys.push(ownerPrivateKey);

        threshold = 2;

        singleton = address(new Safe());
        safeProxyFactory = new SafeProxyFactory();

        bytes memory initializer = abi.encodeWithSelector(
            Safe.setup.selector, owners, threshold, address(0), "", address(0), address(0), 0, address(0)
        );
        safe = Safe(payable(safeProxyFactory.createProxyWithNonce(singleton, initializer, 0)));

        safeSubscriptions = new SafeSubscriptions(address(safe));

        bytes memory enableModuleCallData =
            abi.encodeWithSelector(safe.enableModule.selector, address(safeSubscriptions));
        uint256 gasToUse = 10_000;
        bytes memory enableModuleTransactionData = safe.encodeTransactionData(
            address(safe), 0, enableModuleCallData, Enum.Operation.Call, gasToUse, 0, 0, address(0), payable(0), 0
        );
        (uint8 v1, bytes32 r1, bytes32 s1) = vm.sign(privateKeys[0], keccak256(enableModuleTransactionData));
        (uint8 v2, bytes32 r2, bytes32 s2) = vm.sign(privateKeys[1], keccak256(enableModuleTransactionData));
        bytes memory signatures = abi.encodePacked(abi.encodePacked(r1, s1, v1), abi.encodePacked(r2, s2, v2));
        safe.execTransaction(
            address(safe),
            0,
            enableModuleCallData,
            Enum.Operation.Call,
            gasToUse,
            0,
            0,
            address(0),
            payable(0),
            signatures
        );
    }
}
