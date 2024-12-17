// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { IERC20 } from "@openzeppelin/token/ERC20/IERC20.sol";

import { EIP712 } from "@openzeppelin/utils/cryptography/EIP712.sol";
import { Safe } from "@safe/Safe.sol";
import { Enum } from "@safe/common/Enum.sol";

import { ISafeSubscriptions } from "./interfaces/ISafeSubscriptions.sol";

/// @title SafeSubscriptions.
/// @author mgnfy-view.
/// @notice SafeSubscriptions is a Gnosis Safe module that allows safe multisigs to manage web3 subscriptions.
contract SafeSubscriptions is EIP712, ISafeSubscriptions {
    address private constant NATIVE_TOKEN = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    bytes32 private constant SUBSCRIPTION_TYPEHASH = keccak256(
        bytes(
            "Subscription(address serviceProvider,address token,uint256 amount,uint256 startingTimestamp,uint256 duration,uint256 rounds,uint256 isRecurring,uint256 roundsClaimedSoFar,uint256 salt)"
        )
    );

    /// @dev The address of the multisig this module is attached to.
    Safe private s_safe;
    /// @dev Nonce to be used by signatures. Prevents replay attacks.
    uint256 private s_nonce;
    /// @dev Maps hash of a subscription to it's data.
    mapping(bytes32 subscriptionDataHash => Subscription subscription) private s_subscriptions;
    /// @dev Marks whether a subscription has been cancelled or not.
    mapping(bytes32 subscriptionDataHash => bool isCancelled) private s_isCancelled;

    /// @notice Initializes the safe multisig address and the EIP712 name and version parameters.
    /// @param _safe The address of the multisig this module is attached to.
    constructor(address _safe) EIP712("Safe Subscriptions", "1") {
        s_safe = Safe(payable(_safe));
    }

    /// @notice Allows owners of the multisig to create a new subscription if `threshold` valid signatures
    /// have been provided.
    /// @param _subscription The subscription details.
    /// @param _deadline The expiry time for signatures.
    /// @param _nonce Prevents replay attacks.
    /// @param _signatures A set of `threshold` valid signatures from the multisig owners.
    /// @return The subscription hash/identifier.
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

    /// @notice Allows owners of the multisig to cancel an existing subscription if `threshold` valid signatures
    /// have been provided.
    /// @param _subscriptionDataHash The subscription hash/identifier.
    /// @param _deadline The expiry time for signatures.
    /// @param _nonce Prevents replay attacks.
    /// @param _signatures A set of `threshold` valid signatures from the multisig owners.
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

    /// @notice Anyone can call this function to claim the subscription amount from the multisig on
    /// behalf of the service provider.
    /// @dev If past subscription amounts have not been collected, it can be collected any time in the future.
    /// @param _subscriptionDataHash The subscription hash/identifier.
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

    /// @notice Reverts if the deadline has passed.
    /// @param _deadline The expiry timestamp.
    function _checkDeadline(uint256 _deadline) internal view {
        if (_deadline < block.timestamp) revert DeadlinePassed(_deadline, block.timestamp);
    }

    /// @notice Reverts if an incorrect nonce is used.
    /// @param _nonce The nonce value.
    function _checkNonce(uint256 _nonce) internal view {
        if (_nonce != s_nonce + 1) revert InvalidNonce(_nonce, s_nonce + 1);
    }

    /// @notice Gets the encoded subscription data which can be hashed to create an identifier for the subscription.
    /// @param _subscription The subscription details.
    /// @return Abi encoded subscription data.
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

    /// @notice Gets the encoded subscription details with deadline and nonce parameters factored in.
    /// @param _subscription The subscription details.
    /// @param _deadline The expiry time for signatures.
    /// @param _nonce Prevents replay attacks.
    /// @return The abi encoded subscription data with deadline and nonce values.
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

    /// @notice Gets the address of the safe proxy this module is attached to.
    /// @return The address of the safe proxy this module is attached to.
    function getSafe() external view returns (address) {
        return address(s_safe);
    }

    /// @notice Gets the next valid nonce to be used for creating or cancelling subscriptions.
    /// @return The next valid nonce.
    function getNextNonce() external view returns (uint256) {
        return s_nonce + 1;
    }

    /// @notice Gets the subscription details for the given subscription hash/identifier.
    /// @return The subscription details.
    function getSubscriptionData(bytes32 _subscriptionDataHash) external view returns (Subscription memory) {
        return s_subscriptions[_subscriptionDataHash];
    }

    /// @notice Checks if the subscription for the given subscription hash/identifier has been cancelled or not.
    /// @return A boolean indicating if the subscription has been cancelled or not.
    function isSubscriptionCancelled(bytes32 _subscriptionDataHash) external view returns (bool) {
        return s_isCancelled[_subscriptionDataHash];
    }

    /// @notice Gets both the abi encoded subscription data as well as its hash.
    /// @param _subscription The subscription details.
    /// @param _deadline The expiry time for signatures.
    /// @param _nonce Prevents replay attacks.
    /// @return Abi encoded subscription data with deadline and nonce values.
    /// @return Hash of the abi encoded subscription data with deadline and nonce values.
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

    /// @notice Gets the hash/identifier for the given subscription details.
    /// @return The subscription hash/identifier.
    function getSubscriptionDataHash(Subscription memory _subscription) public pure returns (bytes32) {
        return keccak256(_getEncodedSubscriptionData(_subscription));
    }
}
