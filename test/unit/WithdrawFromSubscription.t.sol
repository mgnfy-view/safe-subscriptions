// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { IERC20 } from "@openzeppelin/token/ERC20/IERC20.sol";

import { ISafeSubscriptions } from "../../src/interfaces/ISafeSubscriptions.sol";

import { GlobalHelper } from "../utils/GlobalHelper.sol";

contract WithdrawFromSubscriptionTest is GlobalHelper {
    function test_withdrawingFromSubscriptionFailsIfSubscriptionDoesNotExist() public {
        (ISafeSubscriptions.Subscription memory subscriptionData,,) = _getTestCreateSubscriptionData();
        bytes32 subscriptionDataHash = safeSubscriptions.getSubscriptionDataHash(subscriptionData);

        vm.expectRevert(
            abi.encodeWithSelector(ISafeSubscriptions.SubscriptionDoesNotExist.selector, subscriptionDataHash)
        );
        safeSubscriptions.withdrawFromSubscription(subscriptionDataHash);
    }

    function test_withdrawingFromSubscriptionFailsIfSubscriptionDoesHasBeenCancelled() public {
        bytes32 subscriptionDataHash = _createTestSubscription();
        ISafeSubscriptions.Subscription memory subscriptionData =
            safeSubscriptions.getSubscriptionData(subscriptionDataHash);
        uint256 deadline = block.timestamp + delay;
        uint256 nonce = safeSubscriptions.getNextNonce();
        bytes memory signatures = _getSignaturesForSubscriptionOperation(subscriptionData, deadline, nonce);

        safeSubscriptions.cancelSubscription(subscriptionDataHash, deadline, nonce, signatures);

        vm.expectRevert(ISafeSubscriptions.SubscriptionRevoked.selector);
        safeSubscriptions.withdrawFromSubscription(subscriptionDataHash);
    }

    function test_withdrawingFromSubscriptionFailsIfSubscriptionHasNotStartedYet() public {
        (ISafeSubscriptions.Subscription memory subscription, uint256 deadline, uint256 nonce) =
            _getTestCreateSubscriptionData();
        subscription.startingTimestamp = block.timestamp + delay;
        bytes memory signatures = _getSignaturesForSubscriptionOperation(subscription, deadline, nonce);

        safeSubscriptions.createSubscription(subscription, deadline, nonce, signatures);

        bytes32 subscriptionDataHash = safeSubscriptions.getSubscriptionDataHash(subscription);
        vm.expectRevert(
            abi.encodeWithSelector(ISafeSubscriptions.SubscriptionHasNotStartedYet.selector, subscriptionDataHash)
        );
        safeSubscriptions.withdrawFromSubscription(subscriptionDataHash);
    }

    function test_withdrawNativeTokenFromSubscriptionOnce() public {
        uint256 amountToDeal = 1 ether;
        vm.deal(address(safe), amountToDeal);
        bytes32 subscriptionDataHash = _createTestSubscription();

        _warpBy(duration);

        uint256 serviceProviderBalanceBefore = serviceProvider.balance;
        safeSubscriptions.withdrawFromSubscription(subscriptionDataHash);
        uint256 serviceProviderBalanceAfter = serviceProvider.balance;

        ISafeSubscriptions.Subscription memory subscriptionData =
            safeSubscriptions.getSubscriptionData(subscriptionDataHash);
        assertEq(serviceProviderBalanceAfter - serviceProviderBalanceBefore, amount);
        assertEq(subscriptionData.roundsClaimedSoFar, rounds - 1);
    }

    function test_withdrawNativeTokenFromSubscriptionOverTime() public {
        uint256 amountToDeal = 1 ether;
        vm.deal(address(safe), amountToDeal);
        bytes32 subscriptionDataHash = _createTestSubscription();

        _warpBy(duration);

        uint256 serviceProviderBalanceBefore = serviceProvider.balance;
        safeSubscriptions.withdrawFromSubscription(subscriptionDataHash);
        uint256 serviceProviderBalanceAfter = serviceProvider.balance;

        ISafeSubscriptions.Subscription memory subscriptionData =
            safeSubscriptions.getSubscriptionData(subscriptionDataHash);
        assertEq(serviceProviderBalanceAfter - serviceProviderBalanceBefore, amount);
        assertEq(subscriptionData.roundsClaimedSoFar, rounds - 1);

        _warpBy(duration);

        serviceProviderBalanceBefore = serviceProvider.balance;
        safeSubscriptions.withdrawFromSubscription(subscriptionDataHash);
        serviceProviderBalanceAfter = serviceProvider.balance;

        subscriptionData = safeSubscriptions.getSubscriptionData(subscriptionDataHash);
        assertEq(serviceProviderBalanceAfter - serviceProviderBalanceBefore, amount);
        assertEq(subscriptionData.roundsClaimedSoFar, rounds);
    }

    function test_withdrawNativeTokenFromSubscriptionFromAllRounds() public {
        uint256 amountToDeal = 1 ether;
        vm.deal(address(safe), amountToDeal);
        bytes32 subscriptionDataHash = _createTestSubscription();

        _warpBy(duration * rounds);

        uint256 serviceProviderBalanceBefore = serviceProvider.balance;
        safeSubscriptions.withdrawFromSubscription(subscriptionDataHash);
        uint256 serviceProviderBalanceAfter = serviceProvider.balance;

        ISafeSubscriptions.Subscription memory subscriptionData =
            safeSubscriptions.getSubscriptionData(subscriptionDataHash);
        assertEq(serviceProviderBalanceAfter - serviceProviderBalanceBefore, amount * rounds);
        assertEq(subscriptionData.roundsClaimedSoFar, rounds);
    }

    function test_withdrawNativeTokenFromRecurringSubscription() public {
        uint256 amountToDeal = 1 ether;
        vm.deal(address(safe), amountToDeal);
        uint256 roundsToClaim = 3;
        (ISafeSubscriptions.Subscription memory subscription, uint256 deadline, uint256 nonce) =
            _getTestCreateSubscriptionData();
        subscription.isRecurring = true;
        bytes memory signatures = _getSignaturesForSubscriptionOperation(subscription, deadline, nonce);

        bytes32 subscriptionDataHash = safeSubscriptions.createSubscription(subscription, deadline, nonce, signatures);

        _warpBy(duration * roundsToClaim);

        uint256 serviceProviderBalanceBefore = serviceProvider.balance;
        safeSubscriptions.withdrawFromSubscription(subscriptionDataHash);
        uint256 serviceProviderBalanceAfter = serviceProvider.balance;

        ISafeSubscriptions.Subscription memory subscriptionData =
            safeSubscriptions.getSubscriptionData(subscriptionDataHash);
        assertEq(serviceProviderBalanceAfter - serviceProviderBalanceBefore, amount * roundsToClaim);
        assertEq(subscriptionData.roundsClaimedSoFar, roundsToClaim);
    }

    function test_withdrawERC20TokensFromSubscriptionOnce() public {
        token.mint(address(safe), amount);
        (ISafeSubscriptions.Subscription memory subscription, uint256 deadline, uint256 nonce) =
            _getTestCreateSubscriptionData();
        subscription.token = address(token);
        bytes memory signatures = _getSignaturesForSubscriptionOperation(subscription, deadline, nonce);

        bytes32 subscriptionDataHash = safeSubscriptions.createSubscription(subscription, deadline, nonce, signatures);

        _warpBy(duration);

        uint256 serviceProviderBalanceBefore = IERC20(address(token)).balanceOf(serviceProvider);
        safeSubscriptions.withdrawFromSubscription(subscriptionDataHash);
        uint256 serviceProviderBalanceAfter = IERC20(address(token)).balanceOf(serviceProvider);

        ISafeSubscriptions.Subscription memory subscriptionData =
            safeSubscriptions.getSubscriptionData(subscriptionDataHash);
        assertEq(serviceProviderBalanceAfter - serviceProviderBalanceBefore, amount);
        assertEq(subscriptionData.roundsClaimedSoFar, rounds - 1);
    }

    function test_withdrawERC20TokensFromSubscriptionOverTime() public {
        token.mint(address(safe), amount * rounds);
        (ISafeSubscriptions.Subscription memory subscription, uint256 deadline, uint256 nonce) =
            _getTestCreateSubscriptionData();
        subscription.token = address(token);
        bytes memory signatures = _getSignaturesForSubscriptionOperation(subscription, deadline, nonce);

        bytes32 subscriptionDataHash = safeSubscriptions.createSubscription(subscription, deadline, nonce, signatures);

        _warpBy(duration);

        uint256 serviceProviderBalanceBefore = IERC20(address(token)).balanceOf(serviceProvider);
        safeSubscriptions.withdrawFromSubscription(subscriptionDataHash);
        uint256 serviceProviderBalanceAfter = IERC20(address(token)).balanceOf(serviceProvider);

        ISafeSubscriptions.Subscription memory subscriptionData =
            safeSubscriptions.getSubscriptionData(subscriptionDataHash);
        assertEq(serviceProviderBalanceAfter - serviceProviderBalanceBefore, amount);
        assertEq(subscriptionData.roundsClaimedSoFar, rounds - 1);

        _warpBy(duration);

        serviceProviderBalanceBefore = IERC20(address(token)).balanceOf(serviceProvider);
        safeSubscriptions.withdrawFromSubscription(subscriptionDataHash);
        serviceProviderBalanceAfter = IERC20(address(token)).balanceOf(serviceProvider);

        subscriptionData = safeSubscriptions.getSubscriptionData(subscriptionDataHash);
        assertEq(serviceProviderBalanceAfter - serviceProviderBalanceBefore, amount);
        assertEq(subscriptionData.roundsClaimedSoFar, rounds);
    }

    function test_withdrawERC20TokensFromSubscriptionFromAllRounds() public {
        token.mint(address(safe), amount * rounds);
        (ISafeSubscriptions.Subscription memory subscription, uint256 deadline, uint256 nonce) =
            _getTestCreateSubscriptionData();
        subscription.token = address(token);
        bytes memory signatures = _getSignaturesForSubscriptionOperation(subscription, deadline, nonce);

        bytes32 subscriptionDataHash = safeSubscriptions.createSubscription(subscription, deadline, nonce, signatures);

        _warpBy(duration * rounds);

        uint256 serviceProviderBalanceBefore = IERC20(address(token)).balanceOf(serviceProvider);
        safeSubscriptions.withdrawFromSubscription(subscriptionDataHash);
        uint256 serviceProviderBalanceAfter = IERC20(address(token)).balanceOf(serviceProvider);

        ISafeSubscriptions.Subscription memory subscriptionData =
            safeSubscriptions.getSubscriptionData(subscriptionDataHash);
        assertEq(serviceProviderBalanceAfter - serviceProviderBalanceBefore, amount * rounds);
        assertEq(subscriptionData.roundsClaimedSoFar, rounds);
    }

    function test_withdrawERC20TokensFromRecurringSubscription() public {
        token.mint(address(safe), amount * 3);
        uint256 roundsToClaim = 3;
        (ISafeSubscriptions.Subscription memory subscription, uint256 deadline, uint256 nonce) =
            _getTestCreateSubscriptionData();
        subscription.token = address(token);
        subscription.isRecurring = true;
        bytes memory signatures = _getSignaturesForSubscriptionOperation(subscription, deadline, nonce);

        bytes32 subscriptionDataHash = safeSubscriptions.createSubscription(subscription, deadline, nonce, signatures);

        _warpBy(duration * roundsToClaim);

        uint256 serviceProviderBalanceBefore = IERC20(address(token)).balanceOf(serviceProvider);
        safeSubscriptions.withdrawFromSubscription(subscriptionDataHash);
        uint256 serviceProviderBalanceAfter = IERC20(address(token)).balanceOf(serviceProvider);

        ISafeSubscriptions.Subscription memory subscriptionData =
            safeSubscriptions.getSubscriptionData(subscriptionDataHash);
        assertEq(serviceProviderBalanceAfter - serviceProviderBalanceBefore, amount * roundsToClaim);
        assertEq(subscriptionData.roundsClaimedSoFar, roundsToClaim);
    }

    function test_withdrawingTokenFromSubscriptionEmitsEvent() public {
        uint256 amountToDeal = 1 ether;
        vm.deal(address(safe), amountToDeal);
        bytes32 subscriptionDataHash = _createTestSubscription();

        _warpBy(duration);

        vm.expectEmit(true, true, true, true);
        emit ISafeSubscriptions.FundsWithdrawnFromSubscription(subscriptionDataHash, amount);
        safeSubscriptions.withdrawFromSubscription(subscriptionDataHash);
    }
}
