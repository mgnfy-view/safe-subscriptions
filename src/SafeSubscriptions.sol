// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { IERC20 } from "@openzeppelin/token/ERC20/IERC20.sol";

import { EIP712 } from "@openzeppelin/utils/cryptography/EIP712.sol";
import { Safe } from "@safe/Safe.sol";
import { Enum } from "@safe/common/Enum.sol";

import { ISafeSubscriptions } from "./interfaces/ISafeSubscriptions.sol";

contract SafeSubscriptions is EIP712, ISafeSubscriptions {
    address private constant NATIVE_TOKEN = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    bytes32 private constant SUBSCRIPTION_TYPEHASH = keccak256(
        bytes(
            "Subscription(address serviceProvider,address token,uint256 amount,uint256 startingTimestamp,uint256 duration,uint256 rounds,uint256 isRecurring,uint256 roundsClaimedSoFar,uint256 salt)"
        )
    );

    Safe private s_safe;
    uint256 private s_nonce;
    mapping(bytes32 subscriptionDataHash => Subscription subscription) private s_subscriptions;
    mapping(bytes32 subscriptionDataHash => bool isCancelled) private s_isCancelled;

    constructor(address _safe) EIP712("Safe Subscriptions", "1") {
        s_safe = Safe(payable(_safe));
    }

    function createSubscription(
        Subscription memory _subscription,
        uint256 _deadline,
        uint256 _nonce,
        bytes memory _signatures
    )
        external
        returns (bytes32)
    {
        if (
            _subscription.serviceProvider == address(0) || _subscription.token == address(0)
                || _subscription.amount == 0 || _subscription.startingTimestamp < block.timestamp
                || _subscription.duration == 0 || _subscription.rounds == 0 || _subscription.roundsClaimedSoFar > 0
        ) revert InvalidSubscription();

        (bytes memory encodedSubscriptionDataWithDeadlineAndNonce, bytes32 subscriptionDataWithDeadlineAndNonceHash) =
            getEncodedSubscriptionDataAndHash(_subscription, _deadline, _nonce);
        s_safe.checkNSignatures(
            subscriptionDataWithDeadlineAndNonceHash,
            encodedSubscriptionDataWithDeadlineAndNonce,
            _signatures,
            s_safe.getThreshold()
        );

        _checkDeadline(_deadline);
        _checkNonce(_nonce);

        bytes32 subscriptionDataHash = getSubscriptionDataHash(_subscription);
        if (s_subscriptions[subscriptionDataHash].serviceProvider != address(0)) {
            revert SubscriptionAlreadyExists(subscriptionDataHash);
        }
        s_subscriptions[subscriptionDataHash] = _subscription;
        s_nonce++;

        emit SubscriptionCreated(_subscription);

        return subscriptionDataHash;
    }

    function cancelSubscription(
        bytes32 _subscriptionDataHash,
        uint256 _deadline,
        uint256 _nonce,
        bytes memory _signatures
    )
        external
    {
        Subscription memory subscription = s_subscriptions[_subscriptionDataHash];

        if (subscription.serviceProvider == address(0)) revert SubscriptionDoesNotExist(_subscriptionDataHash);

        (bytes memory subscriptionDataWithDeadlineAndNonce, bytes32 subscriptionDataWithDeadlineAndNonceHash) =
            getEncodedSubscriptionDataAndHash(subscription, _deadline, _nonce);
        s_safe.checkNSignatures(
            subscriptionDataWithDeadlineAndNonceHash,
            subscriptionDataWithDeadlineAndNonce,
            _signatures,
            s_safe.getThreshold()
        );

        _checkDeadline(_deadline);
        _checkNonce(_nonce);

        s_isCancelled[_subscriptionDataHash] = true;
        s_nonce++;

        emit SubscriptionCancelled(_subscriptionDataHash);
    }

    function withdrawFromSubscription(bytes32 _subscriptionDataHash) external {
        Subscription memory subscription = s_subscriptions[_subscriptionDataHash];

        if (subscription.serviceProvider == address(0)) revert SubscriptionDoesNotExist(_subscriptionDataHash);
        if (s_isCancelled[_subscriptionDataHash]) revert SubscriptionRevoked();
        if (subscription.startingTimestamp > block.timestamp) {
            revert SubscriptionHasNotStartedYet(_subscriptionDataHash);
        }

        uint256 roundsToClaim;
        if (subscription.isRecurring) {
            roundsToClaim = ((block.timestamp - subscription.startingTimestamp) / subscription.duration)
                - subscription.roundsClaimedSoFar;
        } else {
            roundsToClaim = (block.timestamp - subscription.startingTimestamp) / subscription.duration;
            if (roundsToClaim > subscription.rounds) roundsToClaim = subscription.rounds;
            roundsToClaim -= subscription.roundsClaimedSoFar;
        }
        uint256 amountToWithdraw = roundsToClaim * subscription.amount;
        if (amountToWithdraw == 0) revert ZeroAmountToWithdraw();
        s_subscriptions[_subscriptionDataHash].roundsClaimedSoFar += roundsToClaim;

        bool success;
        if (subscription.token == NATIVE_TOKEN) {
            success = s_safe.execTransactionFromModule(
                subscription.serviceProvider, amountToWithdraw, "", Enum.Operation.Call
            );
        } else {
            bytes memory tokenTransferCallData =
                abi.encodeWithSelector(IERC20.transfer.selector, subscription.serviceProvider, amountToWithdraw);
            success =
                s_safe.execTransactionFromModule(subscription.token, 0, tokenTransferCallData, Enum.Operation.Call);
        }
        if (!success) revert TransactionFailed();

        emit FundsWithdrawnFromSubscription(_subscriptionDataHash, amountToWithdraw);
    }

    function _checkDeadline(uint256 _deadline) internal view {
        if (_deadline < block.timestamp) revert DeadlinePassed(_deadline, block.timestamp);
    }

    function _checkNonce(uint256 _nonce) internal view {
        if (_nonce != s_nonce + 1) revert InvalidNonce(_nonce, s_nonce + 1);
    }

    function _getEncodedSubscriptionData(Subscription memory _subscription) internal pure returns (bytes memory) {
        return abi.encodePacked(
            SUBSCRIPTION_TYPEHASH,
            _subscription.token,
            _subscription.serviceProvider,
            _subscription.amount,
            _subscription.startingTimestamp,
            _subscription.duration,
            _subscription.rounds,
            _subscription.isRecurring,
            _subscription.roundsClaimedSoFar,
            _subscription.salt
        );
    }

    function _getEncodedSubscriptionDataWithDeadlineAndNonce(
        Subscription memory _subscription,
        uint256 _deadline,
        uint256 _nonce
    )
        internal
        pure
        returns (bytes memory)
    {
        bytes memory encodedSubscriptionData = _getEncodedSubscriptionData(_subscription);

        return abi.encodePacked(encodedSubscriptionData, _deadline, _nonce);
    }

    function getSafe() external view returns (address) {
        return address(s_safe);
    }

    function getNextNonce() external view returns (uint256) {
        return s_nonce + 1;
    }

    function getSubscriptionData(bytes32 _subscriptionDataHash) external view returns (Subscription memory) {
        return s_subscriptions[_subscriptionDataHash];
    }

    function isSubscriptionCancelled(bytes32 _subscriptionDataHash) external view returns (bool) {
        return s_isCancelled[_subscriptionDataHash];
    }

    function getEncodedSubscriptionDataAndHash(
        Subscription memory _subscription,
        uint256 _deadline,
        uint256 _nonce
    )
        public
        view
        returns (bytes memory, bytes32)
    {
        bytes memory encodedSubscriptionDataWithDeadlineAndNonce =
            _getEncodedSubscriptionDataWithDeadlineAndNonce(_subscription, _deadline, _nonce);

        return (
            encodedSubscriptionDataWithDeadlineAndNonce,
            _hashTypedDataV4(keccak256(encodedSubscriptionDataWithDeadlineAndNonce))
        );
    }

    function getSubscriptionDataHash(Subscription memory _subscription) public pure returns (bytes32) {
        return keccak256(_getEncodedSubscriptionData(_subscription));
    }
}
