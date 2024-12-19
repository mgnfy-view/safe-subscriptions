# ISafeSubscriptions
[Git Source](https://github.com/mgnfy-view/safe-subscriptions/blob/afae2266cf372f06ed0f14e9e93730ce80fbbe96/src/interfaces/ISafeSubscriptions.sol)


## Functions
### createSubscription


```solidity
function createSubscription(
    Subscription memory _subscription,
    uint256 _deadline,
    uint256 _nonce,
    bytes memory _signatures
)
    external
    returns (bytes32);
```

### cancelSubscription


```solidity
function cancelSubscription(
    bytes32 _subscriptionDataHash,
    uint256 _deadline,
    uint256 _nonce,
    bytes memory _signatures
)
    external;
```

### withdrawFromSubscription


```solidity
function withdrawFromSubscription(bytes32 _subscriptionDataHash) external;
```

### getSafe


```solidity
function getSafe() external view returns (address);
```

### getNextNonce


```solidity
function getNextNonce() external view returns (uint256);
```

### getSubscriptionData


```solidity
function getSubscriptionData(bytes32 _subscriptionDataHash) external view returns (Subscription memory);
```

### isSubscriptionCancelled


```solidity
function isSubscriptionCancelled(bytes32 _subscriptionDataHash) external view returns (bool);
```

### getEncodedSubscriptionDataAndHash


```solidity
function getEncodedSubscriptionDataAndHash(
    Subscription memory _subscription,
    uint256 _deadline,
    uint256 _nonce
)
    external
    view
    returns (bytes memory, bytes32);
```

### getSubscriptionDataHash


```solidity
function getSubscriptionDataHash(Subscription memory _subscription) external pure returns (bytes32);
```

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

