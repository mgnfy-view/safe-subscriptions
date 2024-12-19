// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

interface ISafeSubscriptions {
    /// @notce Subscription details.
    struct Subscription {
        /// @dev The recipient of the subscription amount.
        address serviceProvider;
        /// @dev The payment token -- either the native token, or an ERC20 token.
        address token;
        /// @dev The amount to emit in each round.
        uint256 amount;
        /// @dev The UNIX timestamp (in seconds) when this subscription begins.
        uint256 startingTimestamp;
        /// @dev The duration of each round.
        uint256 duration;
        /// @dev The number of rounds set. Ignored if `isRecurring` is set to true.
        uint256 rounds;
        /// @dev Recurring subscriptions go on forever until they are manually cancelled.
        bool isRecurring;
        /// @dev The number of rounds claimed by the service provider since the start of
        /// the subscription.
        uint256 roundsClaimedSoFar;
        /// @notice A unique value to prevent hash collisions between other subscriptions
        /// with the same configuration.
        uint256 salt;
    }

    event SubscriptionCreated(Subscription indexed subscription);
    event SubscriptionCancelled(bytes32 indexed subscriptionDataHash);
    event FundsWithdrawnFromSubscription(bytes32 indexed subscriptionDataHash, uint256 indexed amountToWithdraw);

    error InvalidSubscription();
    error SubscriptionAlreadyExists(bytes32 subscriptionDataHash);
    error SubscriptionDoesNotExist(bytes32 subscriptionDataHash);
    error SubscriptionRevoked();
    error SubscriptionHasNotStartedYet(bytes32 subscriptionDataHash);
    error ZeroAmountToWithdraw();
    error TransactionFailed();
    error DeadlinePassed(uint256 deadline, uint256 currentTimestamp);
    error InvalidNonce(uint256 givenNonce, uint256 expectedNonce);

    function createSubscription(
        Subscription memory _subscription,
        uint256 _deadline,
        uint256 _nonce,
        bytes memory _signatures
    )
        external
        returns (bytes32);
    function cancelSubscription(
        bytes32 _subscriptionDataHash,
        uint256 _deadline,
        uint256 _nonce,
        bytes memory _signatures
    )
        external;
    function withdrawFromSubscription(bytes32 _subscriptionDataHash) external;
    function getSafe() external view returns (address);
    function getNextNonce() external view returns (uint256);
    function getSubscriptionData(bytes32 _subscriptionDataHash) external view returns (Subscription memory);
    function isSubscriptionCancelled(bytes32 _subscriptionDataHash) external view returns (bool);
    function getEncodedSubscriptionDataAndHash(
        Subscription memory _subscription,
        uint256 _deadline,
        uint256 _nonce
    )
        external
        view
        returns (bytes memory, bytes32);
    function getSubscriptionDataHash(Subscription memory _subscription) external pure returns (bytes32);
}
