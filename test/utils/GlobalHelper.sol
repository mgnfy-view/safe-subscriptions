// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Test } from "forge-std/Test.sol";

import { Safe } from "@safe/Safe.sol";
import { Enum } from "@safe/common/Enum.sol";
import { SafeProxy } from "@safe/proxies/SafeProxy.sol";
import { SafeProxyFactory } from "@safe/proxies/SafeProxyFactory.sol";

import { ISafeSubscriptions } from "../../src/interfaces/ISafeSubscriptions.sol";

import { SafeSubscriptions } from "../../src/SafeSubscriptions.sol";

contract GlobalHelper is Test {
    address public constant NATIVE_TOKEN = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    address[] public owners;
    uint256[] public privateKeys;
    uint256 public threshold;

    SafeSubscriptions public safeSubscriptions;

    address public singleton;
    SafeProxyFactory public safeProxyFactory;
    Safe public safe;

    address public serviceProvider;
    uint256 public amount;
    uint256 public startingTimestamp;
    uint256 public duration;
    uint256 public rounds;
    bool public isRecurring;
    uint256 public salt;
    uint256 public delay;

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

        serviceProvider = makeAddr("Service provider");
        amount = 0.1 ether;
        duration = 30 days;
        rounds = 2;
        delay = 2 minutes;
    }

    function _getTestCreateSubscriptionData()
        internal
        view
        returns (ISafeSubscriptions.Subscription memory, uint256, uint256)
    {
        ISafeSubscriptions.Subscription memory subscription = ISafeSubscriptions.Subscription({
            serviceProvider: serviceProvider,
            token: NATIVE_TOKEN,
            amount: amount,
            startingTimestamp: block.timestamp,
            duration: duration,
            rounds: rounds,
            isRecurring: isRecurring,
            roundsClaimedSoFar: 0,
            salt: salt
        });
        uint256 deadline = block.timestamp + delay;
        uint256 nonce = safeSubscriptions.getNextNonce();

        return (subscription, deadline, nonce);
    }

    function _getSignaturesForSubscriptionCreation(
        ISafeSubscriptions.Subscription memory _subscription,
        uint256 _deadline,
        uint256 _nonce
    )
        internal
        returns (bytes memory)
    {
        (, bytes32 subscriptionDataHash) =
            safeSubscriptions.getEncodedSubscriptionDataAndHash(_subscription, _deadline, _nonce);

        (uint8 v1, bytes32 r1, bytes32 s1) = vm.sign(privateKeys[0], subscriptionDataHash);
        (uint8 v2, bytes32 r2, bytes32 s2) = vm.sign(privateKeys[1], subscriptionDataHash);
        bytes memory signatures = abi.encodePacked(abi.encodePacked(r1, s1, v1), abi.encodePacked(r2, s2, v2));

        return signatures;
    }

    function _warpBy(uint256 _duration) internal {
        vm.warp(block.timestamp + _duration);
    }
}
