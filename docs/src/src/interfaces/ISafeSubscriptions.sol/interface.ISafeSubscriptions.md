# ISafeSubscriptions
[Git Source](https://github.com/mgnfy-view/safe-subscriptions/blob/ee23a85b61e1a2fcb6f4711abea433f68c6a08e4/src/interfaces/ISafeSubscriptions.sol)


## Events
### SubscriptionCreated

```solidity
event SubscriptionCreated(Subscription indexed subscription);
```

### SubscriptionCancelled

```solidity
event SubscriptionCancelled(bytes32 indexed subscriptionDataHash);
```

### FundsWithdrawnFromSubscription

```solidity
event FundsWithdrawnFromSubscription(bytes32 indexed subscriptionDataHash, uint256 indexed amountToWithdraw);
```

## Errors
### InvalidSubscription

```solidity
error InvalidSubscription();
```

### SubscriptionAlreadyExists

```solidity
error SubscriptionAlreadyExists(bytes32 subscriptionDataHash);
```

### SubscriptionDoesNotExist

```solidity
error SubscriptionDoesNotExist(bytes32 subscriptionDataHash);
```

### SubscriptionRevoked

```solidity
error SubscriptionRevoked();
```

### SubscriptionHasNotStartedYet

```solidity
error SubscriptionHasNotStartedYet(bytes32 subscriptionDataHash);
```

### ZeroAmountToWithdraw

```solidity
error ZeroAmountToWithdraw();
```

### TransactionFailed

```solidity
error TransactionFailed();
```

### DeadlinePassed

```solidity
error DeadlinePassed(uint256 deadline, uint256 currentTimestamp);
```

### InvalidNonce

```solidity
error InvalidNonce(uint256 givenNonce, uint256 expectedNonce);
```

## Structs
### Subscription

```solidity
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
```

