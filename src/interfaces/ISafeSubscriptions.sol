// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

interface ISafeSubscriptions {
    struct Subscription {
        address serviceProvider;
        address token;
        uint256 amount;
        uint256 startingTimestamp;
        uint256 duration;
        uint256 rounds;
        bool isRecurring;
        uint256 roundsClaimedSoFar;
        uint256 salt;
    }

    event SubscriptionCreated(Subscription indexed subscription);
    event SubscriptionCancelled(bytes32 indexed subscriptionDataHash);
    event FundsWithdrawnFromSubscription(bytes32 indexed subscriptionDataHash, uint256 indexed amountToWithdraw);

    error InvalidSubscription();
    error SubscriptionAlreadyExists(bytes32 subscriptionDataHash);
    error SubscriptionDoesNotExist(bytes32 subscriptionDataHash);
    error SubscriptionHasNotStartedYet(bytes32 subscriptionDataHash);
    error TransactionFailed();
    error UnauthorizedUpgrade(address caller, address upgradeAuthority);
    error DeadlinePassed(uint256 deadline, uint256 currentTimestamp);
    error InvalidNonce(uint256 givenNonce, uint256 _expectedNonce);
}
