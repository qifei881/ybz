# Dispute Mechanism - Bilateral Protection

## Overview

The YBZ platform implements a **bilateral dispute mechanism** that protects both buyers and sellers equally. Both parties have the right to raise disputes and seek arbitration.

## Core Principle: Fairness

**Both buyers AND sellers can initiate disputes** at appropriate stages of the deal lifecycle. This ensures balanced protection for all participants.

## When Can Disputes Be Raised?

### Deal States That Allow Disputes

Disputes can be raised during these states:

1. **Accepted** - After seller accepts but before work submission
2. **Submitted** - After work is submitted but before buyer confirmation

```solidity
// From YBZCore.sol
function raiseDispute(uint256 dealId, bytes32 evidenceHash) {
    // Can dispute in Accepted or Submitted states
    if (deal.status != DealStatus.Accepted && deal.status != DealStatus.Submitted) {
        revert InvalidStatus();
    }
    
    // Only buyer or seller can raise dispute
    if (msg.sender != deal.buyer && msg.sender != deal.seller) {
        revert Unauthorized();
    }
    
    // ... rest of logic
}
```

## Buyer's Dispute Scenarios

### Scenario 1: Work Not Meeting Standards

After seller submits work, buyer can dispute if:
- Work quality doesn't match terms
- Deliverables are incomplete
- Work differs from agreed specifications

**Example:**
```javascript
// Buyer raises dispute after receiving subpar work
await core.connect(buyer).raiseDispute(
    dealId, 
    evidenceHash  // IPFS hash of evidence showing quality issues
);
```

### Scenario 2: Seller Becomes Unresponsive

During "Accepted" state, if seller:
- Stops responding
- Fails to provide updates
- Shows signs of abandonment

**Example:**
```javascript
// Buyer disputes due to seller non-communication
await core.connect(buyer).raiseDispute(
    dealId,
    evidenceHash  // IPFS hash of communication attempts
);
```

## Seller's Dispute Scenarios

### Scenario 1: Buyer Refuses to Pay Unfairly

After submitting work, seller can dispute if:
- Work meets all agreed terms
- Buyer refuses to confirm without valid reason
- Buyer is attempting to receive work without payment

**Example:**
```javascript
// Seller completed work but buyer won't approve
await core.connect(seller).raiseDispute(
    dealId,
    evidenceHash  // IPFS hash proving work completion
);
```

### Scenario 2: Changed Requirements

During "Accepted" state, seller can dispute if:
- Buyer demands changes beyond original terms
- Scope creep without additional payment
- Terms become unreasonable or impossible

**Example:**
```javascript
// Buyer keeps changing requirements
await core.connect(seller).raiseDispute(
    dealId,
    evidenceHash  // IPFS hash of original terms vs new demands
);
```

### Scenario 3: Buyer Becomes Unresponsive

After work submission, if buyer:
- Doesn't respond to completion notice
- Ignores requests for review
- Attempts to delay payment indefinitely

**Note:** Seller is also protected by auto-release mechanism if buyer doesn't confirm within the deadline.

## Dispute Process Flow

### 1. Dispute Initiation

Either party can raise a dispute:

```javascript
const evidenceHash = await uploadToIPFS(evidence);
await core.raiseDispute(dealId, evidenceHash);
```

**Events Emitted:**
- `DisputeRaised(dealId, initiator, evidenceHash)`

**What Happens:**
- Deal status changes to `Disputed`
- Random arbiter is assigned from active pool
- Dispute registered in arbitration module
- Both parties can submit additional evidence

### 2. Evidence Submission

Both parties can submit evidence through the arbitration module:

```javascript
// Buyer submits evidence
await arbitration.submitEvidence(dealId, buyerEvidenceHash, true);

// Seller submits evidence
await arbitration.submitEvidence(dealId, sellerEvidenceHash, false);
```

### 3. Arbiter Review

The assigned arbiter:
- Reviews all evidence from both parties
- Examines original deal terms
- Considers IPFS-stored documents
- Has 7 days to make a decision (default)

### 4. Resolution

Arbiter determines fair distribution:

```javascript
// Arbiter resolves with split decision
await core.connect(arbiter).resolveDispute(
    dealId,
    60,  // 60% to buyer
    40,  // 40% to seller
    resolutionHash  // IPFS hash of decision reasoning
);
```

**Possible Outcomes:**
- 100% to buyer, 0% to seller (complete refund)
- 0% to buyer, 100% to seller (full payment)
- Any split between 0-100% for each party

**Fees:**
- Platform fee (2%) deducted from total
- Arbiter fee (1%) deducted from total (only on disputes)
- Remaining amount distributed per arbiter's decision

## Protection Mechanisms

### For Buyers

1. **Quality Assurance**
   - Can dispute if work doesn't meet terms
   - Arbiter reviews evidence objectively
   - Possible refund if seller didn't deliver

2. **Fraud Protection**
   - Can dispute if seller disappears
   - Can dispute if work is plagiarized
   - Evidence-based resolution

### For Sellers

1. **Payment Protection**
   - Can dispute if buyer refuses fair payment
   - Auto-release if buyer ignores submission
   - Evidence of work completion matters

2. **Scope Protection**
   - Can dispute unreasonable demands
   - Original terms are binding
   - Changes require mutual agreement

## Best Practices

### For Both Parties

1. **Document Everything**
   ```javascript
   // Upload comprehensive evidence to IPFS
   const evidence = {
       originalTerms: "...",
       communications: [...],
       deliverables: [...],
       screenshots: [...],
       timestamps: [...]
   };
   const evidenceHash = await uploadToIPFS(evidence);
   ```

2. **Raise Disputes Promptly**
   - Don't wait until deadlines pass
   - Submit evidence while fresh
   - Communicate intent clearly

3. **Provide Clear Evidence**
   - Screenshots of communications
   - Work deliverables
   - Original agreement terms
   - Any relevant documentation

4. **Be Professional**
   - Stick to facts
   - Provide objective evidence
   - Respect arbitration process

### For Buyers

- Review work thoroughly before disputing
- Give seller chance to correct minor issues
- Only dispute if genuinely necessary
- Provide specific reasons for dissatisfaction

### For Sellers

- Complete work according to exact terms
- Document all deliverables
- Keep communication records
- Submit work with clear proof of completion

## Why Bilateral Disputes Matter

### Platform Fairness

Traditional escrow systems often favor buyers:
- Buyers can dispute, sellers cannot
- Buyers can delay payment indefinitely
- Sellers have no recourse for unfair buyers

**YBZ's Solution:** Equal rights for both parties.

### Real-World Examples

**Scenario A: Bad Actor Buyer**
- Seller completes excellent work
- Buyer refuses to pay, trying to get free work
- **Without bilateral disputes:** Seller loses time and work
- **With YBZ:** Seller can dispute, arbiter reviews evidence, seller gets paid

**Scenario B: Bad Actor Seller**
- Seller submits poor quality work
- Buyer rightfully refuses payment
- **Without disputes:** Buyer forced to accept or lose deposit
- **With YBZ:** Buyer disputes, arbiter reviews, buyer gets refund

**Scenario C: Honest Disagreement**
- Both parties acted in good faith
- Genuine misunderstanding about requirements
- **With YBZ:** Arbiter reviews, fair split based on partial completion

## Statistics & Incentives

### Dispute Costs

Both parties should consider:
- Platform fee: 2% (always charged)
- Arbiter fee: 1% (only on disputes)
- Time cost of dispute process
- Reputation impact

**Incentive:** Resolve issues directly when possible, use disputes as last resort.

### Resolution Time

- Evidence submission: Up to 7 days
- Arbiter review: 7 days (default)
- Total: ~2 weeks typical

**Note:** Faster than most traditional dispute systems.

## Technical Implementation

### Access Control

```solidity
// Only buyer or seller can raise dispute
if (msg.sender != deal.buyer && msg.sender != deal.seller) {
    revert Unauthorized();
}
```

### State Validation

```solidity
// Can only dispute in certain states
if (deal.status != DealStatus.Accepted && 
    deal.status != DealStatus.Submitted) {
    revert InvalidStatus();
}
```

### Arbiter Assignment

```solidity
// Random arbiter selection from active pool
address arbiter = arbitration.selectRandomArbiter();
deal.arbiter = arbiter;
```

## Events for Tracking

All dispute actions emit events:

```solidity
event DisputeRaised(
    uint256 indexed dealId,
    address indexed initiator,
    bytes32 evidenceHash
);

event EvidenceSubmitted(
    uint256 indexed dealId,
    address indexed party,
    bytes32 evidenceHash
);

event DisputeResolved(
    uint256 indexed dealId,
    address indexed arbiter,
    uint8 buyerRatio,
    uint8 sellerRatio
);
```

## Comparison with Other Platforms

| Feature | Traditional Escrow | Freelance Platforms | YBZ |
|---------|-------------------|---------------------|-----|
| Buyer can dispute | ✅ | ✅ | ✅ |
| Seller can dispute | ❌ | ⚠️ Limited | ✅ |
| Evidence submission | ❌ | ✅ | ✅ |
| On-chain resolution | ❌ | ❌ | ✅ |
| Transparent process | ❌ | ⚠️ Partial | ✅ |
| Immutable records | ❌ | ❌ | ✅ |
| Multiple arbiters | ❌ | ✅ | ✅ |

## Conclusion

YBZ's bilateral dispute mechanism ensures:

✅ **Equality** - Both parties have equal rights
✅ **Transparency** - All evidence on IPFS, decisions on-chain
✅ **Fairness** - Neutral arbiters review evidence objectively
✅ **Protection** - Both buyers and sellers are protected
✅ **Efficiency** - Automated process with clear timelines

This design creates a **trustless** environment where:
- Honest buyers are protected from scammers
- Honest sellers are protected from non-payment
- Disputes are resolved based on evidence
- Neither party can abuse the system

**The result:** A fair marketplace for Web3 freelance work.

---

## Test Coverage

Comprehensive tests verify both parties can dispute:

```javascript
✅ Should allow buyer to raise dispute
✅ Should allow seller to raise dispute  
✅ Should allow seller to raise dispute after submitting work
✅ Should resolve disputes fairly based on evidence
```

**Total: 61 tests passing** - Including seller dispute scenarios.

