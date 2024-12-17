// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { ISafeSubscriptions } from "../../src/interfaces/ISafeSubscriptions.sol";

import { GlobalHelper } from "../utils/GlobalHelper.sol";

contract CreateSubscriptionTest is GlobalHelper {
    function test_creatingANewSubscriptionFailsIfServiceProviderIsAddressZero() public {
        (ISafeSubscriptions.Subscription memory subscription, uint256 deadline, uint256 nonce) =
            _getTestCreateSubscriptionData();
        subscription.serviceProvider = address(0);

        vm.expectRevert(ISafeSubscriptions.InvalidSubscription.selector);
        safeSubscriptions.createSubscription(subscription, deadline, nonce, "");
    }

    function test_creatingANewSubscriptionFailsIfTokenIsAddressZero() public {
        (ISafeSubscriptions.Subscription memory subscription, uint256 deadline, uint256 nonce) =
            _getTestCreateSubscriptionData();
        subscription.token = address(0);

        vm.expectRevert(ISafeSubscriptions.InvalidSubscription.selector);
        safeSubscriptions.createSubscription(subscription, deadline, nonce, "");
    }

    function test_creatingANewSubscriptionFailsIfAmountIsZero() public {
        (ISafeSubscriptions.Subscription memory subscription, uint256 deadline, uint256 nonce) =
            _getTestCreateSubscriptionData();
        subscription.amount = 0;

        vm.expectRevert(ISafeSubscriptions.InvalidSubscription.selector);
        safeSubscriptions.createSubscription(subscription, deadline, nonce, "");
    }

    function test_creatingANewSubscriptionFailsIfStartingTimestampIsLessThanCurrentTimestamp() public {
        (ISafeSubscriptions.Subscription memory subscription, uint256 deadline, uint256 nonce) =
            _getTestCreateSubscriptionData();

        _warpBy(1);

        vm.expectRevert(ISafeSubscriptions.InvalidSubscription.selector);
        safeSubscriptions.createSubscription(subscription, deadline, nonce, "");
    }

    function test_creatingANewSubscriptionFailsIfDurationIsZero() public {
        (ISafeSubscriptions.Subscription memory subscription, uint256 deadline, uint256 nonce) =
            _getTestCreateSubscriptionData();
        subscription.duration = 0;

        vm.expectRevert(ISafeSubscriptions.InvalidSubscription.selector);
        safeSubscriptions.createSubscription(subscription, deadline, nonce, "");
    }

    function test_creatingANewSubscriptionFailsIfRoundsIsZero() public {
        (ISafeSubscriptions.Subscription memory subscription, uint256 deadline, uint256 nonce) =
            _getTestCreateSubscriptionData();
        subscription.rounds = 0;

        vm.expectRevert(ISafeSubscriptions.InvalidSubscription.selector);
        safeSubscriptions.createSubscription(subscription, deadline, nonce, "");
    }

    function test_creatingANewSubscriptionFailsIfRoundsClaimedSoFarIsGreaterThanZero() public {
        (ISafeSubscriptions.Subscription memory subscription, uint256 deadline, uint256 nonce) =
            _getTestCreateSubscriptionData();
        subscription.roundsClaimedSoFar = 1;

        vm.expectRevert(ISafeSubscriptions.InvalidSubscription.selector);
        safeSubscriptions.createSubscription(subscription, deadline, nonce, "");
    }

    function test_creatingANewSubscriptionFailsIfInvalidSignatureIsPassed() public {
        (ISafeSubscriptions.Subscription memory subscription, uint256 deadline, uint256 nonce) =
            _getTestCreateSubscriptionData();

        vm.expectRevert();
        safeSubscriptions.createSubscription(subscription, deadline, nonce, "");
    }

    function test_creatingANewSubscriptionFailsIfDeadlineHasPassed() public {
        (ISafeSubscriptions.Subscription memory subscription, uint256 deadline, uint256 nonce) =
            _getTestCreateSubscriptionData();
        subscription.startingTimestamp = block.timestamp + 2 * delay;
        bytes memory signatures = _getSignaturesForSubscriptionOperation(subscription, deadline, nonce);

        _warpBy(delay + 1);

        vm.expectRevert(abi.encodeWithSelector(ISafeSubscriptions.DeadlinePassed.selector, deadline, block.timestamp));
        safeSubscriptions.createSubscription(subscription, deadline, nonce, signatures);
    }

    function test_creatingANewSubscriptionFailsIfInvalidNonceIsUsed() public {
        (ISafeSubscriptions.Subscription memory subscription, uint256 deadline, uint256 nonce) =
            _getTestCreateSubscriptionData();
        nonce = 10;
        bytes memory signatures = _getSignaturesForSubscriptionOperation(subscription, deadline, nonce);

        vm.expectRevert(
            abi.encodeWithSelector(ISafeSubscriptions.InvalidNonce.selector, nonce, safeSubscriptions.getNextNonce())
        );
        safeSubscriptions.createSubscription(subscription, deadline, nonce, signatures);
    }

    function test_creatingANewSubscriptionSucceeds() public {
        (ISafeSubscriptions.Subscription memory subscription, uint256 deadline, uint256 nonce) =
            _getTestCreateSubscriptionData();
        bytes memory signatures = _getSignaturesForSubscriptionOperation(subscription, deadline, nonce);

        bytes32 subscriptionDataHash = safeSubscriptions.createSubscription(subscription, deadline, nonce, signatures);

        ISafeSubscriptions.Subscription memory subscriptionData =
            safeSubscriptions.getSubscriptionData(subscriptionDataHash);
        assertEq(subscriptionData.serviceProvider, subscription.serviceProvider);
        assertEq(subscriptionData.token, subscription.token);
        assertEq(subscriptionData.amount, subscription.amount);
        assertEq(subscriptionData.startingTimestamp, subscription.startingTimestamp);
        assertEq(subscriptionData.duration, subscription.duration);
        assertEq(subscriptionData.rounds, subscription.rounds);
        assertEq(subscriptionData.isRecurring, subscription.isRecurring);
        assertEq(subscriptionData.roundsClaimedSoFar, subscription.roundsClaimedSoFar);
        assertEq(subscriptionData.salt, subscription.salt);

        assertEq(safeSubscriptions.getNextNonce(), nonce + 1);
    }

    function test_creatingANewSubscriptionEmitsEvent() public {
        (ISafeSubscriptions.Subscription memory subscription, uint256 deadline, uint256 nonce) =
            _getTestCreateSubscriptionData();
        bytes memory signatures = _getSignaturesForSubscriptionOperation(subscription, deadline, nonce);

        vm.expectEmit(true, true, true, true);
        emit ISafeSubscriptions.SubscriptionCreated(subscription);
        safeSubscriptions.createSubscription(subscription, deadline, nonce, signatures);
    }
}
