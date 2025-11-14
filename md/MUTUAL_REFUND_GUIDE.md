# Mutual Refund Guide - Collaborative Cancellation

## Overview

The YBZ platform supports **mutual refund agreements** where both parties can agree to cancel a deal before completion. This feature handles scenarios where the seller discovers they cannot fulfill the order and wants to refund the buyer amicably.

## The Problem This Solves

### Before: Forced to Wait for Deadline

**Scenario:**
```
Day 1: Buyer creates order for custom product (5 ETH)
Day 1: Seller accepts order
Day 2: Seller discovers product is out of stock
Day 2: Seller contacts buyer privately: "Sorry, can't fulfill"
Day 2: Both parties want to cancel...
      ❌ But must wait 7 days until submitDeadline!
Day 8: Finally can cancel with cancelDeal()
```

**Problems:**
- Buyer's funds locked for 7 days unnecessarily
- Seller can't move on to other orders
- Poor user experience
- Inefficient capital usage

### After: Instant Mutual Agreement

**Scenario:**
```
Day 1: Buyer creates order (5 ETH)
Day 1: Seller accepts
Day 2: Seller discovers issue, contacts buyer
Day 2: Buyer calls requestRefund()
Day 2: Seller calls approveRefund()
        ✅ Instant refund! (0 fees)
```

**Benefits:**
- ✅ Immediate resolution
- ✅ No waiting period
- ✅ No fees (goodwill gesture)
- ✅ Better user experience
- ✅ Professional handling

## How It Works

### Two-Step Process

**Step 1: Buyer Requests Refund**
```solidity
function requestRefund(uint256 dealId) external
```

**Step 2: Seller Approves Refund**
```solidity
function approveRefund(uint256 dealId) external
```

### Flow Diagram

```
┌─────────────────┐
│  Deal Created   │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Seller Accepts  │
└────────┬────────┘
         │
         ▼
┌──────────────────────────┐
│ Seller discovers issue   │
│ (no stock, can't deliver)│
└────────┬─────────────────┘
         │
         ▼
┌──────────────────────────┐
│ Seller contacts Buyer    │
│ privately (off-chain)    │
└────────┬─────────────────┘
         │
         ▼
┌──────────────────────────┐
│ Buyer: requestRefund()   │
│ ✓ Sets refund flag       │
└────────┬─────────────────┘
         │
         ▼
┌──────────────────────────┐
│ Seller: approveRefund()  │
│ ✓ Full refund (0 fees)   │
│ ✓ Deal cancelled         │
└────────┬─────────────────┘
         │
         ▼
┌─────────────────┐
│  Deal Closed    │
│ (Storage deleted)│
└─────────────────┘
```

## Usage Examples

### Example 1: Out of Stock

```javascript
// Seller discovers they don't have the item

// 1. Seller contacts buyer (off-chain)
// "Sorry, we're out of stock. Can we cancel?"

// 2. Buyer agrees and requests refund (on-chain)
await core.connect(buyer).requestRefund(dealId);

// Event emitted:
// RefundRequested(dealId, buyer)

// 3. Seller approves refund (on-chain)
await core.connect(seller).approveRefund(dealId);

// Events emitted:
// RefundApproved(dealId, seller)
// DealCancelled(dealId, seller, "Mutual agreement - seller approved refund")
// FundsReleased(dealId, buyer, 5 ETH)

// Result: Buyer gets full 5 ETH back (no fees)
```

### Example 2: Seller Can't Meet Deadline

```javascript
// Seller accepted but realizes timeline is impossible

// Off-chain communication:
// Seller: "This will take 2 months, not 1 month as agreed"
// Buyer: "That's too long for me, let's cancel"

// On-chain:
await core.connect(buyer).requestRefund(dealId);
await core.connect(seller).approveRefund(dealId);

// Buyer refunded immediately, can find another seller
```

### Example 3: Quality Concern Before Delivery

```javascript
// Seller submits work but realizes it's not good enough

// 1. Seller submits work
await core.connect(seller).submitWork(dealId, deliveryHash);

// 2. Seller reviews own work, not satisfied
// "I don't want to deliver subpar work, let's refund"

// 3. Mutual agreement to refund
await core.connect(buyer).requestRefund(dealId);
await core.connect(seller).approveRefund(dealId);

// Both parties maintain good relationship
```

## Technical Details

### When Can It Be Used?

**Allowed States:**
- ✅ `Accepted` - After seller accepts, before work submitted
- ✅ `Submitted` - After work submitted, before buyer confirms

**Not Allowed States:**
- ❌ `Created` - Use autoCancel instead
- ❌ `Disputed` - Already in arbitration
- ❌ `Approved` - Already completed
- ❌ `Cancelled` - Already cancelled

### Access Control

```javascript
// requestRefund()
// - Only buyer can call
// - Can be called in Accepted or Submitted states

// approveRefund()
// - Only seller can call
// - Requires refundRequested = true
// - Can be called in Accepted or Submitted states
```

### No Fees on Mutual Refund

```solidity
// Full refund - no deductions
_transferFunds(deal.token, deal.buyer, deal.amount);

// If deal was 10 ETH:
// - Buyer receives: 10 ETH (100%)
// - Platform fee: 0 ETH
// - Arbiter fee: 0 ETH
```

**Rationale:**
- Mutual agreement is a goodwill gesture
- Neither party at fault
- Encourages professional behavior
- Rewards honest communication

### State Changes

```javascript
// Before requestRefund():
deal.refundRequested = false;

// After requestRefund():
deal.refundRequested = true;
deal.status = Accepted (or Submitted) // unchanged

// After approveRefund():
deal.status = Cancelled;
// Then storage deleted via _closeDeal()
```

## Real-World Scenarios

### Scenario 1: Custom Manufacturing

```
Product: Custom electronics (50 ETH)
Day 1: Buyer orders, seller accepts
Day 5: Seller discovers component shortage
Day 5: Seller: "Components unavailable for 6 months"
Day 5: Buyer: "Too long, I need it next month"
Day 5: Mutual refund executed
Result: Buyer finds alternative supplier immediately
```

### Scenario 2: Freelance Design

```
Service: Logo design (2 ETH)
Day 1: Buyer orders, seller accepts
Day 2: Seller has family emergency
Day 2: Seller: "Can't complete, sorry"
Day 2: Buyer: "No problem, hope everything's ok"
Day 2: Instant refund
Result: Professional relationship maintained
```

### Scenario 3: Software Development

```
Service: App development (100 ETH)
Day 1: Agreement, seller accepts
Day 3: Seller reviews requirements deeper
Day 3: Seller: "This needs technology we don't have"
Day 3: Buyer: "Let's cancel, I'll find specialist"
Day 3: Refund processed
Result: Clean break, no hard feelings
```

## Security Features

### 1. Two-Step Verification

```javascript
// Seller CANNOT unilaterally cancel and take money
// Seller CANNOT approve refund without buyer request

// Step 1 required (buyer consent):
await core.connect(buyer).requestRefund(dealId);

// Step 2 required (seller consent):
await core.connect(seller).approveRefund(dealId);
```

### 2. Role Enforcement

```javascript
// Only buyer can request
function requestRefund(uint256 dealId) external {
    requireAuthorized(deal, msg.sender, true);  // buyer only
}

// Only seller can approve
function approveRefund(uint256 dealId) external {
    requireAuthorized(deal, msg.sender, false);  // seller only
}
```

### 3. Request Validation

```javascript
function approveRefund(uint256 dealId) external {
    require(deal.refundRequested, "No refund request");
    // Cannot approve without request
}
```

### 4. Reentrancy Protection

```javascript
function approveRefund(uint256 dealId) 
    external 
    override 
    nonReentrant  // ✓ Protected
    whenNotPaused 
{
    // ... refund logic
}
```

## Comparison: Mutual Refund vs. cancelDeal

| Feature | Mutual Refund | cancelDeal |
|---------|--------------|------------|
| **Timing** | Anytime | After submitDeadline only |
| **Requires** | Both parties agree | Deadline passed |
| **Fees** | 0% (goodwill) | 0% (timeout) |
| **Speed** | Instant | Must wait for deadline |
| **Use Case** | Seller can't fulfill | Seller ghosted/failed |
| **Relationship** | Maintains goodwill | Seller at fault |

## Best Practices

### For Sellers

1. **Be Honest Early**
   ```
   ❌ Bad: Accept order, disappear, wait for timeout
   ✅ Good: Realize issue, contact buyer, mutual refund
   ```

2. **Communicate Off-Chain First**
   ```
   Step 1: Message buyer explaining situation
   Step 2: Ask if refund is acceptable
   Step 3: Wait for buyer to request on-chain
   Step 4: Approve promptly
   ```

3. **Don't Abuse**
   ```
   ❌ Don't accept many orders then cancel all
   ⚠️ Reputation matters (future feature)
   ✅ Only use when genuinely necessary
   ```

### For Buyers

1. **Be Understanding**
   ```
   Seller contacts with legitimate issue?
   → Consider mutual refund
   → Maintains platform ecosystem health
   ```

2. **Request Promptly**
   ```
   If you agree to refund, request it quickly
   Don't leave seller waiting
   ```

3. **Document Agreement**
   ```
   Keep off-chain communications
   Evidence of mutual agreement
   Useful if any dispute later
   ```

## Frontend Integration

### Check Refund Status

```javascript
const deal = await core.getDeal(dealId);

if (deal.refundRequested) {
    // Show "Refund Requested" badge
    // If user is seller, show "Approve Refund" button
}
```

### Request Refund Flow

```javascript
// 1. Show confirmation dialog
const confirmed = await confirmDialog(
    "Request Refund",
    "This will ask the seller to approve a full refund. Continue?",
    "Request",
    "Cancel"
);

if (!confirmed) return;

// 2. Execute transaction
const tx = await core.requestRefund(dealId);
await tx.wait();

// 3. Show success message
showNotification(
    "Refund Requested",
    "Seller will be notified. If they approve, you'll receive full refund.",
    "success"
);

// 4. Notify seller (off-chain)
await notifyUser(sellerAddress, {
    type: "REFUND_REQUESTED",
    dealId: dealId,
    message: "Buyer has requested a refund"
});
```

### Approve Refund Flow

```javascript
// 1. Show refund details
const deal = await core.getDeal(dealId);

const confirmed = await confirmDialog(
    "Approve Refund",
    `Buyer will receive ${formatEther(deal.amount)} ETH (full refund, no fees). Approve?`,
    "Approve",
    "Decline"
);

if (!confirmed) return;

// 2. Execute approval
const tx = await core.approveRefund(dealId);
await tx.wait();

// 3. Show success
showNotification(
    "Refund Approved",
    "Buyer has been refunded. Thank you for being professional.",
    "success"
);

// 4. Notify buyer
await notifyUser(buyerAddress, {
    type: "REFUND_APPROVED",
    dealId: dealId,
    amount: deal.amount
});
```

## Events

### RefundRequested

```solidity
event RefundRequested(
    uint256 indexed dealId,
    address indexed buyer
);
```

**When:** Buyer calls `requestRefund()`
**Purpose:** Notify seller of refund request

### RefundApproved

```solidity
event RefundApproved(
    uint256 indexed dealId,
    address indexed seller
);
```

**When:** Seller calls `approveRefund()`
**Purpose:** Confirm refund execution

## FAQ

### Q: What if seller doesn't approve?

**A:** Buyer can still:
- Wait for submitDeadline to pass
- Then call `cancelDeal()` for full refund
- Mutual refund is faster, but not required

### Q: Can seller request refund?

**A:** No, only buyer can request. This prevents sellers from forcing cancellations. Seller's consent is through approving the buyer's request.

### Q: What if buyer requests but seller denies?

**A:** Seller simply doesn't call `approveRefund()`. The deal continues normally. Seller can still submit work.

### Q: Does this affect deadlines?

**A:** No. All deadlines remain active. Mutual refund is just a faster alternative to waiting for deadlines.

### Q: Can I cancel my refund request?

**A:** Not directly. But seller can simply not approve. The request flag stays set, but deal continues if seller submits work or buyer approves.

### Q: Is there a time limit to approve?

**A:** No explicit limit. But practical limit is the confirmDeadline. After that, deal auto-releases to seller anyway.

## Summary

### Key Benefits

✅ **Instant Resolution** - No waiting for deadlines
✅ **Zero Fees** - Full refund on mutual agreement  
✅ **Professional** - Handles honest mistakes gracefully  
✅ **Flexible** - Works in Accepted or Submitted states  
✅ **Secure** - Requires both parties' consent  

### Use Cases

🎯 **Out of Stock** - Seller can't source item  
🎯 **Timeline Issues** - Can't meet deadline  
🎯 **Technical Limitations** - Lacks required skills/tools  
🎯 **Quality Concerns** - Seller's work not up to standard  
🎯 **Changed Circumstances** - Unforeseen issues  

### Process

```
1. Seller discovers issue
2. Seller contacts buyer off-chain
3. Both parties agree to refund
4. Buyer calls requestRefund() on-chain
5. Seller calls approveRefund() on-chain
6. Buyer receives 100% refund
7. Deal closed, both move on
```

---

**Version:** 1.0  
**Last Updated:** 2025-10-18  
**Test Coverage:** 5/5 passing ✅  
**Status:** Production Ready ✅

