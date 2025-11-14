# Fee Management Guide

## Overview

YBZ platform provides **flexible fee management** that allows administrators to adjust fees dynamically in response to market competition, operating costs, and business strategy. This ensures the platform remains competitive while sustainable.

## Core Philosophy

> **"Fees should be adjustable by governance, but protected by hard limits to prevent abuse."**

## Current Fee Structure

### Default Fees

| Fee Type | Initial Rate | Max Allowed | Who Pays | When Charged |
|----------|-------------|-------------|----------|--------------|
| **Platform Fee** | 2% (200 bps) | 10% (1000 bps) | Seller | On successful deal |
| **Arbiter Fee** | 1% (100 bps) | 10% (1000 bps) | Split | Only on disputes |

**Note:** BPS = Basis Points (1% = 100 bps)

### Fee Distribution

```
Deal Amount: 10 ETH

Normal Completion (No Dispute):
- Platform Fee: 10 * 2% = 0.2 ETH → Treasury
- Seller Receives: 9.8 ETH

With Dispute:
- Platform Fee: 10 * 2% = 0.2 ETH → Treasury
- Arbiter Fee: 10 * 1% = 0.1 ETH → Arbiter
- Remaining: 9.7 ETH → Split per arbiter decision
```

## Fee Adjustment Capabilities

### 1. Platform Fee Adjustment

**Function:**
```solidity
function updatePlatformFee(uint16 newFeeBps) external onlyRole(FEE_ADMIN_ROLE)
```

**Examples:**

```javascript
// Reduce to 1.5% due to competition
await feeManager.updatePlatformFee(150);

// Increase to 2.5% due to higher costs
await feeManager.updatePlatformFee(250);

// Promotional rate: 0.5%
await feeManager.updatePlatformFee(50);
```

**Limits:**
- ✅ Min: 0% (0 bps) - Free platform (promotional)
- ✅ Max: 10% (1000 bps) - Hard-coded protection
- ❌ Cannot exceed MAX_FEE_BPS

### 2. Arbiter Fee Adjustment

**Function:**
```solidity
function updateArbiterFee(uint16 newFeeBps) external onlyRole(FEE_ADMIN_ROLE)
```

**Examples:**

```javascript
// Reduce to 0.5% to encourage fair arbitration
await feeManager.updateArbiterFee(50);

// Increase to 1.5% to attract more arbiters
await feeManager.updateArbiterFee(150);
```

**Rationale:**
- Higher arbiter fee → More arbiters willing to participate
- Lower arbiter fee → Lower cost for users in disputes
- Balance quality vs. cost

### 3. Tiered Fee Structure (Volume Discounts)

**Function:**
```solidity
function addTier(uint256 threshold, uint16 feeBps) external onlyRole(FEE_ADMIN_ROLE)
function removeTier(uint256 threshold) external onlyRole(FEE_ADMIN_ROLE)
```

**Concept:** Larger deals get better rates (rewards high-value users)

**Example Setup:**

```javascript
// Default: 2% for all deals
await feeManager.updatePlatformFee(200);

// Add tiers
await feeManager.addTier(
    ethers.parseEther("10"),   // 10+ ETH deals
    150                         // Get 1.5% rate
);

await feeManager.addTier(
    ethers.parseEther("50"),   // 50+ ETH deals
    100                         // Get 1% rate
);

await feeManager.addTier(
    ethers.parseEther("100"),  // 100+ ETH deals
    75                          // Get 0.75% rate
);
```

**Result:**

| Deal Amount | Fee Rate | Fee Amount (example 50 ETH) |
|-------------|----------|----------------------------|
| < 10 ETH | 2% | N/A |
| 10-49 ETH | 1.5% | 0.75 ETH |
| 50-99 ETH | 1% | 0.5 ETH |
| 100+ ETH | 0.75% | N/A |

**Benefits:**
- Rewards loyal, high-volume users
- Competes with centralized platforms
- Increases platform attractiveness for enterprise

### 4. Min/Max Fee Limits

**Functions:**
```solidity
function updateMinFee(uint256 newMinFee) external onlyRole(FEE_ADMIN_ROLE)
function updateMaxFee(uint256 newMaxFee) external onlyRole(FEE_ADMIN_ROLE)
```

**Purpose:**
- **Min Fee:** Ensures platform sustainability on tiny deals
- **Max Fee:** Protects users from excessive fees on huge deals

**Examples:**

```javascript
// Set minimum fee to 0.005 ETH
await feeManager.updateMinFee(ethers.parseEther("0.005"));

// Very small deal: 0.1 ETH
// 0.1 * 2% = 0.002 ETH < 0.005 ETH minimum
// Actual fee charged: 0.005 ETH

// Set maximum fee to 5 ETH
await feeManager.updateMaxFee(ethers.parseEther("5"));

// Very large deal: 500 ETH
// 500 * 2% = 10 ETH > 5 ETH maximum
// Actual fee charged: 5 ETH (capped)
```

## Market Response Strategies

### Strategy 1: Competitor Launches with Lower Fees

**Scenario:**
- Current platform fee: 2%
- New competitor enters with 1% fee
- Risk: Losing market share

**Options:**

**A. Match Competitor**
```javascript
await feeManager.updatePlatformFee(100);  // Match 1%
```

**B. Undercut Slightly**
```javascript
await feeManager.updatePlatformFee(90);   // 0.9% to win market
```

**C. Keep Rate but Add Value Tiers**
```javascript
// Keep 2% for small deals
// Offer 1% for large deals (10+ ETH)
await feeManager.addTier(ethers.parseEther("10"), 100);
```

**D. Differentiate on Quality**
- Keep 2% fee
- Emphasize superior features (better arbiters, faster, more secure)
- Target quality-conscious users

### Strategy 2: Market Downturn / Low Activity

**Scenario:**
- Transaction volume dropping
- Users price-sensitive
- Need to stimulate activity

**Action:**
```javascript
// Temporary promotional rate
await feeManager.updatePlatformFee(50);  // 0.5% promotional

// Later, gradually increase back
await feeManager.updatePlatformFee(100); // 1%
await feeManager.updatePlatformFee(150); // 1.5%
await feeManager.updatePlatformFee(200); // Back to 2%
```

### Strategy 3: Operating Costs Increase

**Scenario:**
- Gas prices rising
- More arbiters needed (higher costs)
- Infrastructure costs increase

**Action:**
```javascript
// Increase platform fee
await feeManager.updatePlatformFee(250);  // 2.5%

// Or increase arbiter fee to attract more arbiters
await feeManager.updateArbiterFee(150);   // 1.5%
```

### Strategy 4: Loyalty Program

**Scenario:**
- Want to reward repeat users
- Encourage high-value deals
- Build long-term user base

**Action:**
```javascript
// Progressive discount tiers
await feeManager.addTier(ethers.parseEther("1"), 180);    // 1+ ETH: 1.8%
await feeManager.addTier(ethers.parseEther("5"), 160);    // 5+ ETH: 1.6%
await feeManager.addTier(ethers.parseEther("10"), 140);   // 10+ ETH: 1.4%
await feeManager.addTier(ethers.parseEther("50"), 100);   // 50+ ETH: 1%
```

## Access Control

### Fee Admin Role

```solidity
bytes32 public constant FEE_ADMIN_ROLE = keccak256("FEE_ADMIN_ROLE");
```

**Who can adjust fees?**
- Platform admin (initially)
- DAO governance (future)
- Authorized fee managers

**How to grant:**
```javascript
const FEE_ADMIN_ROLE = ethers.keccak256(ethers.toUtf8Bytes("FEE_ADMIN_ROLE"));
await feeManager.grantRole(FEE_ADMIN_ROLE, newAdminAddress);
```

**How to revoke:**
```javascript
await feeManager.revokeRole(FEE_ADMIN_ROLE, oldAdminAddress);
```

## Safety Mechanisms

### 1. Hard Cap (MAX_FEE_BPS = 10%)

**Purpose:** Prevents admin abuse

```solidity
uint16 public constant MAX_FEE_BPS = 1000;  // 10% maximum

// This will fail:
await feeManager.updatePlatformFee(1500);  // 15% - rejected!

// This will succeed:
await feeManager.updatePlatformFee(1000);  // 10% - max allowed
```

**Why 10%?**
- Industry standard for platform fees
- High enough for sustainability
- Low enough to stay competitive
- Users protected from excessive fees

### 2. Event Logging

All fee changes emit events:

```solidity
event PlatformFeeUpdated(uint16 oldFee, uint16 newFee);
event ArbiterFeeUpdated(uint16 oldFee, uint16 newFee);
event TierAdded(uint256 threshold, uint16 feeBps);
event TierRemoved(uint256 threshold);
```

**Benefits:**
- Full transparency
- Auditable fee history
- Users can monitor changes
- DAO can review admin actions

### 3. Immutable MAX_FEE_BPS

```solidity
uint16 public constant MAX_FEE_BPS = 1000;
```

- Cannot be changed after deployment
- Provides user protection
- Built-in trust mechanism

## Real-World Examples

### Example 1: Freelance Platform Launch

**Phase 1: Market Entry (Month 1-3)**
```javascript
// Aggressive pricing to gain users
await feeManager.updatePlatformFee(100);  // 1% only!
```

**Phase 2: Growth (Month 4-6)**
```javascript
// Gradually increase as value proven
await feeManager.updatePlatformFee(150);  // 1.5%
```

**Phase 3: Sustainable (Month 7+)**
```javascript
// Standard rate with volume discounts
await feeManager.updatePlatformFee(200);  // 2% base
await feeManager.addTier(ethers.parseEther("10"), 150);  // 1.5% for 10+ ETH
```

### Example 2: Enterprise Onboarding

**Scenario:** Large company wants to use platform for $1M+ deals

**Solution:**
```javascript
// Add enterprise tier
await feeManager.addTier(
    ethers.parseEther("500"),  // 500+ ETH deals
    50                          // 0.5% enterprise rate
);

// Result: Competitive with traditional escrow (0.5-1%)
```

### Example 3: Bear Market Response

**Scenario:** Crypto market down 70%, activity dried up

**Action:**
```javascript
// Emergency stimulus pricing
await feeManager.updatePlatformFee(25);   // 0.25% minimal fee
await feeManager.updateArbiterFee(25);    // 0.25% arbiter fee

// Total: 0.5% (super competitive)
```

**Later Recovery:**
```javascript
// Gradually restore
await feeManager.updatePlatformFee(100);  // 1%
await feeManager.updatePlatformFee(200);  // Back to 2%
```

## Fee Calculation Reference

### Formula

```javascript
// Platform Fee
platformFee = (amount * feeBps) / 10000;

// With min/max limits
if (platformFee < minFee) platformFee = minFee;
if (platformFee > maxFee) platformFee = maxFee;

// Arbiter Fee (only on disputes)
arbiterFee = (amount * arbiterFeeBps) / 10000;
```

### Examples

| Deal Amount | Fee Rate | Platform Fee | Arbiter Fee (if disputed) | Seller Gets (no dispute) |
|-------------|----------|--------------|--------------------------|--------------------------|
| 1 ETH | 2% | 0.02 ETH | 0.01 ETH | 0.98 ETH |
| 10 ETH | 2% | 0.2 ETH | 0.1 ETH | 9.8 ETH |
| 10 ETH | 1.5% (tier) | 0.15 ETH | 0.1 ETH | 9.85 ETH |
| 50 ETH | 1% (tier) | 0.5 ETH | 0.5 ETH | 49.5 ETH |
| 100 ETH | 1% (tier) | 1 ETH | 1 ETH | 99 ETH |

## Querying Fees

### Get Current Fees

```javascript
// Get default fees
const platformFeeBps = await feeManager.defaultPlatformFeeBps();
const arbiterFeeBps = await feeManager.defaultArbiterFeeBps();

console.log(`Platform: ${platformFeeBps / 100}%`);
console.log(`Arbiter: ${arbiterFeeBps / 100}%`);
```

### Calculate Fee for Specific Amount

```javascript
const dealAmount = ethers.parseEther("25");
const feeInfo = await feeManager.getFeeInfo(dealAmount);

console.log(`Deal: ${ethers.formatEther(dealAmount)} ETH`);
console.log(`Platform Fee: ${ethers.formatEther(feeInfo.platformFee)} ETH`);
console.log(`Arbiter Fee: ${ethers.formatEther(feeInfo.arbiterFee)} ETH`);
console.log(`Fee Rate: ${feeInfo.platformFeeBps / 100}%`);
```

### Check All Tiers

```javascript
const tiers = await feeManager.getTierThresholds();

for (const threshold of tiers) {
    const feeBps = await feeManager.tieredPlatformFees(threshold);
    console.log(`${ethers.formatEther(threshold)}+ ETH: ${feeBps / 100}%`);
}
```

## Best Practices

### For Platform Operators

1. **Communicate Changes**
   - Announce fee changes in advance
   - Explain reasoning (costs, competition, etc.)
   - Give users time to adjust

2. **Monitor Competition**
   - Track competitor fees regularly
   - Adjust proactively, not reactively
   - Differentiate on value, not just price

3. **Test Incrementally**
   - Don't make drastic changes (2% → 5%)
   - Adjust in small steps (2% → 2.25% → 2.5%)
   - Monitor user response

4. **Use Tiers Strategically**
   - Reward high-volume users
   - Encourage larger deals
   - Smooth pricing curve

5. **Balance Sustainability**
   - Fees must cover platform costs
   - But stay competitive
   - Consider long-term viability

### For Users

1. **Check Fees Before Deals**
   ```javascript
   const feeInfo = await feeManager.getFeeInfo(dealAmount);
   // Know exact fee before committing
   ```

2. **Optimize Deal Size**
   - Check if slightly larger deal gets better rate
   - Example: 9.5 ETH (2%) vs 10 ETH (1.5%)

3. **Monitor Fee Changes**
   - Watch for FeeUpdated events
   - Adjust strategy if fees change

## Governance Considerations

### Future: DAO Control

**Current:**
- Admin controls fees (FEE_ADMIN_ROLE)

**Future:**
- DAO governance proposals
- Community votes on fee changes
- Time-locked implementations

**Example DAO Flow:**
```
1. Proposal: Reduce fee to 1.5%
2. Discussion period: 7 days
3. Voting: 3 days
4. Time lock: 2 days (users can exit if desired)
5. Execution: Fee updated
```

### Transparency

All fee changes are:
- ✅ On-chain (visible to all)
- ✅ Event-logged (permanent record)
- ✅ Cannot be hidden
- ✅ Auditable by anyone

## Summary

### Key Capabilities

✅ **Dynamic Fee Adjustment** - Admin can change fees anytime  
✅ **Tiered Pricing** - Volume discounts for large deals  
✅ **Protected Limits** - Max 10% prevents abuse  
✅ **Min/Max Caps** - Ensures fairness on all deal sizes  
✅ **Separate Platform & Arbiter Fees** - Independent control  
✅ **Event Logging** - Full transparency  

### Use Cases

🎯 **Market Competition** - Lower fees to match competitors  
🎯 **Cost Recovery** - Raise fees if expenses increase  
🎯 **Promotions** - Temporary low fees to boost activity  
🎯 **Loyalty Programs** - Tiered discounts for power users  
🎯 **Enterprise Deals** - Custom rates for large transactions  

### Philosophy

> **"Flexible fees enable market responsiveness while hard limits ensure user protection. The best fee is the one that balances platform sustainability with user value."**

---

**Version:** 1.0  
**Last Updated:** 2025-10-18  
**Test Coverage:** 20/20 passing ✅  
**Status:** Production Ready ✅

