// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { ISafeSubscriptions } from "../../src/interfaces/ISafeSubscriptions.sol";

import { GlobalHelper } from "../utils/GlobalHelper.sol";

contract CancelSubscriptionTest is GlobalHelper {
    function test_cancellingSubscriptionFailsIfSubscriptionDoesNotExist() public {
        (ISafeSubscriptions.Subscription memory subscriptionData,,) = _getTestCreateSubscriptionData();
        bytes32 subscriptionDataHash = safeSubscriptions.getSubscriptionDataHash(subscriptionData);

        vm.expectRevert(
            abi.encodeWithSelector(ISafeSubscriptions.SubscriptionDoesNotExist.selector, subscriptionDataHash)
        );
        safeSubscriptions.cancelSubscription(subscriptionDataHash, 0, 0, "");
    }

    function test_cancellingSubscriptionFailsIfDeadlineHasPassed() public {
        bytes32 subscriptionDataHash = _createTestSubscription();
        ISafeSubscriptions.Subscription memory subscriptionData =
            safeSubscriptions.getSubscriptionData(subscriptionDataHash);

        _warpBy(delay);

        uint256 deadline = block.timestamp - 1;
        uint256 nonce = safeSubscriptions.getNextNonce();
        bytes memory signatures = _getSignaturesForSubscriptionOperation(subscriptionData, deadline, nonce);

        vm.expectRevert(abi.encodeWithSelector(ISafeSubscriptions.DeadlinePassed.selector, deadline, block.timestamp));
        safeSubscriptions.cancelSubscription(subscriptionDataHash, deadline, nonce, signatures);
    }

    function test_cancellingSubscriptionFailsIfInvalidNonceIsPassed() public {
        bytes32 subscriptionDataHash = _createTestSubscription();
        ISafeSubscriptions.Subscription memory subscriptionData =
            safeSubscriptions.getSubscriptionData(subscriptionDataHash);
        uint256 deadline = block.timestamp + delay;
        uint256 nonce = safeSubscriptions.getNextNonce() + 1;
        bytes memory signatures = _getSignaturesForSubscriptionOperation(subscriptionData, deadline, nonce);

        vm.expectRevert(abi.encodeWithSelector(ISafeSubscriptions.InvalidNonce.selector, nonce, nonce - 1));
        safeSubscriptions.cancelSubscription(subscriptionDataHash, deadline, nonce, signatures);
    }

    function test_cancellingSubscriptionSucceeds() public {
        bytes32 subscriptionDataHash = _createTestSubscription();
        ISafeSubscriptions.Subscription memory subscriptionData =
            safeSubscriptions.getSubscriptionData(subscriptionDataHash);
        uint256 deadline = block.timestamp + delay;
        uint256 nonce = safeSubscriptions.getNextNonce();
        bytes memory signatures = _getSignaturesForSubscriptionOperation(subscriptionData, deadline, nonce);

        safeSubscriptions.cancelSubscription(subscriptionDataHash, deadline, nonce, signatures);

        assertEq(safeSubscriptions.getNextNonce(), nonce + 1);
        assertTrue(safeSubscriptions.isSubscriptionCancelled(subscriptionDataHash));
    }

    function test_cancellingSubscriptionEmitsEvent() public {
        bytes32 subscriptionDataHash = _createTestSubscription();
        ISafeSubscriptions.Subscription memory subscriptionData =
            safeSubscriptions.getSubscriptionData(subscriptionDataHash);
        uint256 deadline = block.timestamp + delay;
        uint256 nonce = safeSubscriptions.getNextNonce();
        bytes memory signatures = _getSignaturesForSubscriptionOperation(subscriptionData, deadline, nonce);

        vm.expectEmit(true, true, true, true);
        emit ISafeSubscriptions.SubscriptionCancelled(subscriptionDataHash);
        safeSubscriptions.cancelSubscription(subscriptionDataHash, deadline, nonce, signatures);
    }
}
