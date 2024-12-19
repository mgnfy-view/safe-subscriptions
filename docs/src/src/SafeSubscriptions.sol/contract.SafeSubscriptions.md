# SafeSubscriptions
[Git Source](https://github.com/mgnfy-view/safe-subscriptions/blob/ee23a85b61e1a2fcb6f4711abea433f68c6a08e4/src/SafeSubscriptions.sol)

**Inherits:**
EIP712, [ISafeSubscriptions](/src/interfaces/ISafeSubscriptions.sol/interface.ISafeSubscriptions.md)

**Author:**
mgnfy-view.

SafeSubscriptions is a Gnosis Safe module that allows safe multisigs to manage web3 subscriptions.


## State Variables
### NATIVE_TOKEN

```solidity
address private constant NATIVE_TOKEN = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
```


### SUBSCRIPTION_TYPEHASH

```solidity
bytes32 private constant SUBSCRIPTION_TYPEHASH = keccak256(
    bytes(
        "Subscription(address serviceProvider,address token,uint256 amount,uint256 startingTimestamp,uint256 duration,uint256 rounds,uint256 isRecurring,uint256 roundsClaimedSoFar,uint256 salt)"
    )
);
```


### s_safe
*The address of the multisig this module is attached to.*


```solidity
Safe private s_safe;
```


### s_nonce
*Nonce to be used by signatures. Prevents replay attacks.*


```solidity
uint256 private s_nonce;
```


### s_subscriptions
*Maps hash of a subscription to it's data.*


```solidity
mapping(bytes32 subscriptionDataHash => Subscription subscription) private s_subscriptions;
```


### s_isCancelled
*Marks whether a subscription has been cancelled or not.*


```solidity
mapping(bytes32 subscriptionDataHash => bool isCancelled) private s_isCancelled;
```


## Functions
### constructor

Initializes the safe multisig address and the EIP712 name and version parameters.


```solidity
constructor(address _safe) EIP712("Safe Subscriptions", "1");
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_safe`|`address`|The address of the multisig this module is attached to.|


### createSubscription

Allows owners of the multisig to create a new subscription if `threshold` valid signatures
have been provided.


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
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_subscription`|`Subscription`|The subscription details.|
|`_deadline`|`uint256`|The expiry time for signatures.|
|`_nonce`|`uint256`|Prevents replay attacks.|
|`_signatures`|`bytes`|A set of `threshold` valid signatures from the multisig owners.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32`|The subscription hash/identifier.|


### cancelSubscription

Allows owners of the multisig to cancel an existing subscription if `threshold` valid signatures
have been provided.


```solidity
function cancelSubscription(
    bytes32 _subscriptionDataHash,
    uint256 _deadline,
    uint256 _nonce,
    bytes memory _signatures
)
    external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_subscriptionDataHash`|`bytes32`|The subscription hash/identifier.|
|`_deadline`|`uint256`|The expiry time for signatures.|
|`_nonce`|`uint256`|Prevents replay attacks.|
|`_signatures`|`bytes`|A set of `threshold` valid signatures from the multisig owners.|


### withdrawFromSubscription

Anyone can call this function to claim the subscription amount from the multisig on
behalf of the service provider.

*If past subscription amounts have not been collected, it can be collected any time in the future.*


```solidity
function withdrawFromSubscription(bytes32 _subscriptionDataHash) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_subscriptionDataHash`|`bytes32`|The subscription hash/identifier.|


### _checkDeadline

Reverts if the deadline has passed.


```solidity
function _checkDeadline(uint256 _deadline) internal view;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_deadline`|`uint256`|The expiry timestamp.|


### _checkNonce

Reverts if an incorrect nonce is used.


```solidity
function _checkNonce(uint256 _nonce) internal view;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_nonce`|`uint256`|The nonce value.|


### _getEncodedSubscriptionData

Gets the encoded subscription data which can be hashed to create an identifier for the subscription.


```solidity
function _getEncodedSubscriptionData(Subscription memory _subscription) internal pure returns (bytes memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_subscription`|`Subscription`|The subscription details.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes`|Abi encoded subscription data.|


### _getEncodedSubscriptionDataWithDeadlineAndNonce

Gets the encoded subscription details with deadline and nonce parameters factored in.


```solidity
function _getEncodedSubscriptionDataWithDeadlineAndNonce(
    Subscription memory _subscription,
    uint256 _deadline,
    uint256 _nonce
)
    internal
    pure
    returns (bytes memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_subscription`|`Subscription`|The subscription details.|
|`_deadline`|`uint256`|The expiry time for signatures.|
|`_nonce`|`uint256`|Prevents replay attacks.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes`|The abi encoded subscription data with deadline and nonce values.|


### getSafe

Gets the address of the safe proxy this module is attached to.


```solidity
function getSafe() external view returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|The address of the safe proxy this module is attached to.|


### getNextNonce

Gets the next valid nonce to be used for creating or cancelling subscriptions.


```solidity
function getNextNonce() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The next valid nonce.|


### getSubscriptionData

Gets the subscription details for the given subscription hash/identifier.


```solidity
function getSubscriptionData(bytes32 _subscriptionDataHash) external view returns (Subscription memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`Subscription`|The subscription details.|


### isSubscriptionCancelled

Checks if the subscription for the given subscription hash/identifier has been cancelled or not.


```solidity
function isSubscriptionCancelled(bytes32 _subscriptionDataHash) external view returns (bool);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|A boolean indicating if the subscription has been cancelled or not.|


### getEncodedSubscriptionDataAndHash

Gets both the abi encoded subscription data as well as its hash.


```solidity
function getEncodedSubscriptionDataAndHash(
    Subscription memory _subscription,
    uint256 _deadline,
    uint256 _nonce
)
    public
    view
    returns (bytes memory, bytes32);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_subscription`|`Subscription`|The subscription details.|
|`_deadline`|`uint256`|The expiry time for signatures.|
|`_nonce`|`uint256`|Prevents replay attacks.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes`|Abi encoded subscription data with deadline and nonce values.|
|`<none>`|`bytes32`|Hash of the abi encoded subscription data with deadline and nonce values.|


### getSubscriptionDataHash

Gets the hash/identifier for the given subscription details.


```solidity
function getSubscriptionDataHash(Subscription memory _subscription) public pure returns (bytes32);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32`|The subscription hash/identifier.|


