# Arbiter Management Guide

## Overview

The YBZ platform supports multiple arbiters to handle disputes efficiently. Administrators with the `ARBITER_ADMIN_ROLE` can manage the arbiter list through add, remove, and modify operations.

## Arbiter Management Functions

### 1. Add Arbiter (增加仲裁员)

```solidity
function registerArbiter(address arbiter) external onlyRole(ARBITER_ADMIN_ROLE)
```

**Purpose:** Register a new arbiter to the platform.

**Features:**
- New arbiters start with a reputation score of 80
- Automatically granted the `ARBITER_ROLE`
- Immediately active and can handle disputes

**Example:**
```javascript
await arbitration.registerArbiter("0x123..."); // Add new arbiter
```

### 2. Remove Arbiter (删除仲裁员)

```solidity
function removeArbiter(address arbiter) external onlyRole(ARBITER_ADMIN_ROLE)
```

**Purpose:** Completely remove an arbiter from the platform.

**Safety Checks:**
- Can only remove arbiters with no pending cases
- Requires: `totalCases == resolvedCases`
- Prevents removal of arbiters with active disputes

**Process:**
1. Removes arbiter from the `arbiterList` array
2. Revokes the `ARBITER_ROLE`
3. Deletes all arbiter data
4. Emits `ArbiterRemoved` event

**Example:**
```javascript
await arbitration.removeArbiter("0x123..."); // Remove arbiter
```

### 3. Deactivate Arbiter (停用仲裁员)

```solidity
function deactivateArbiter(address arbiter) external onlyRole(ARBITER_ADMIN_ROLE)
```

**Purpose:** Temporarily disable an arbiter without removing them.

**Use Cases:**
- Arbiter on vacation
- Temporary suspension
- Under investigation

**Features:**
- Arbiter data is preserved
- Can be reactivated later
- Cannot be selected for new disputes

**Example:**
```javascript
await arbitration.deactivateArbiter("0x123..."); // Pause arbiter
```

### 4. Activate Arbiter (激活仲裁员)

```solidity
function activateArbiter(address arbiter) external onlyRole(ARBITER_ADMIN_ROLE)
```

**Purpose:** Reactivate a previously deactivated arbiter.

**Features:**
- Restores `ARBITER_ROLE`
- Can be selected for new disputes
- All historical data preserved

**Example:**
```javascript
await arbitration.activateArbiter("0x123..."); // Resume arbiter
```

### 5. Update Reputation (修改声誉)

```solidity
function updateReputation(address arbiter, uint256 newReputation) external onlyRole(ARBITER_ADMIN_ROLE)
```

**Purpose:** Modify an arbiter's reputation score.

**Parameters:**
- `newReputation`: Score between 0-100

**Use Cases:**
- Reward good performance
- Penalize poor decisions
- Adjust based on community feedback

**Example:**
```javascript
await arbitration.updateReputation("0x123...", 95); // High performer
await arbitration.updateReputation("0x456...", 60); // Needs improvement
```

## View Functions

### Get All Arbiters

```solidity
function getAllArbiters() external view returns (address[] memory)
```

Returns all registered arbiters (both active and inactive).

### Get Active Arbiters

```solidity
function getActiveArbiters() external view returns (address[] memory)
```

Returns only currently active arbiters who can handle disputes.

### Get Arbiter Info

```solidity
function getArbiterInfo(address arbiter) external view returns (ArbiterInfo memory)
```

Returns detailed information about an arbiter:
- `isActive`: Whether the arbiter is active
- `totalCases`: Total disputes assigned
- `resolvedCases`: Successfully resolved disputes
- `reputation`: Current reputation score (0-100)
- `registeredAt`: Registration timestamp

### Check Active Status

```solidity
function isActiveArbiter(address arbiter) external view returns (bool)
```

Quick check if an arbiter is currently active.

## Arbiter Selection

When a dispute is raised, the system automatically selects a random active arbiter:

```solidity
function selectRandomArbiter() external view returns (address)
```

**Selection Criteria:**
- Only active arbiters are considered
- Pseudo-random selection (based on block data)
- Fails if no active arbiters available

**Production Note:** For production deployment, integrate with Chainlink VRF for true randomness.

## Multi-Arbiter Disputes

For high-value or complex disputes, administrators can enable multi-signature arbitration:

```solidity
function initMultiSigArbitration(
    uint256 dealId,
    address[] memory arbiters,
    uint8 requiredVotes
) external onlyRole(ARBITER_ADMIN_ROLE)
```

**Features:**
- Assign multiple arbiters to a single dispute
- Require consensus from N arbiters
- Average the resolution ratios
- Higher confidence in fair outcomes

**Example:**
```javascript
// Require 2 of 3 arbiters to agree
await arbitration.initMultiSigArbitration(
    dealId,
    ["0xArbiter1", "0xArbiter2", "0xArbiter3"],
    2 // requiredVotes
);
```

## Best Practices

### 1. Minimum Active Arbiters

Always maintain at least 3 active arbiters:
- Ensures availability
- Prevents single point of failure
- Enables load distribution

### 2. Regular Review

Periodically review arbiter performance:
```javascript
const arbiters = await arbitration.getAllArbiters();
for (const arbiter of arbiters) {
    const info = await arbitration.getArbiterInfo(arbiter);
    const successRate = info.resolvedCases / info.totalCases;
    
    if (successRate < 0.9 && info.reputation > 60) {
        // Consider lowering reputation
    }
}
```

### 3. Gradual Removal

Instead of immediate removal:
1. First deactivate the arbiter
2. Wait for all pending cases to resolve
3. Then remove permanently

```javascript
// Step 1: Deactivate
await arbitration.deactivateArbiter(arbiter);

// Step 2: Wait and monitor
const info = await arbitration.getArbiterInfo(arbiter);
if (info.totalCases === info.resolvedCases) {
    // Step 3: Safe to remove
    await arbitration.removeArbiter(arbiter);
}
```

### 4. Emergency Procedures

If an arbiter becomes unresponsive:
1. Immediately deactivate to prevent new assignments
2. Reassign pending cases to other arbiters (admin function)
3. Once cleared, remove the arbiter

## Events

Monitor these events for arbiter management:

- `ArbiterRegistered(address arbiter, uint64 registeredAt)`
- `ArbiterDeactivated(address arbiter)`
- `ArbiterActivated(address arbiter)`
- `ArbiterRemoved(address arbiter)`
- `ReputationUpdated(address arbiter, uint256 newReputation)`

## Access Control

All management functions require the `ARBITER_ADMIN_ROLE`:

```javascript
// Grant admin role to new manager
const ARBITER_ADMIN_ROLE = keccak256("ARBITER_ADMIN_ROLE");
await arbitration.grantRole(ARBITER_ADMIN_ROLE, newAdminAddress);

// Revoke when no longer needed
await arbitration.revokeRole(ARBITER_ADMIN_ROLE, oldAdminAddress);
```

## Summary

The YBZ platform provides comprehensive arbiter management capabilities:

✅ **Add** arbiters - Scale your arbitration capacity  
✅ **Remove** arbiters - Clean up inactive arbiters safely  
✅ **Deactivate/Activate** - Flexible pause/resume  
✅ **Update Reputation** - Performance-based management  
✅ **Multi-arbiter Support** - Multiple arbiters can work in parallel  
✅ **Safety Checks** - Prevents removal of arbiters with pending cases  

This design ensures disputes can be handled efficiently even during high load periods.

