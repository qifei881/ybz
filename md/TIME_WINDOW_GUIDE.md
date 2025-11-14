# Time Window Configuration Guide

## Overview

YBZ platform provides **flexible time windows** that allow buyers to customize deal timelines based on their specific industry and project needs. This guide helps you choose appropriate time windows for different types of work.

## Time Window Parameters

When creating a deal, you must specify three time windows:

```solidity
function createDealETH(
    address seller,
    bytes32 termsHash,
    uint64 acceptWindow,   // Time for seller to accept (seconds)
    uint64 submitWindow,   // Time for seller to deliver work (seconds)
    uint64 confirmWindow,  // Time for buyer to confirm (seconds)
    { value: amount }
)
```

### Allowed Ranges

| Window | Minimum | Maximum | Purpose |
|--------|---------|---------|---------|
| **Accept Window** | 1 hour | 30 days | Seller response time |
| **Submit Window** | 1 hour | 180 days | Work delivery period |
| **Confirm Window** | 1 hour | 30 days | Buyer review period |

## Industry-Specific Recommendations

### 1. Quick Tasks (1-8 hours)

**Industries:**
- Translation (small documents)
- Data entry
- Simple graphics
- Text transcription
- Quick fixes

**Recommended Settings:**

```javascript
// Translation: 500-word document
await core.createDealETH(
    seller,
    termsHash,
    3600,      // 1 hour accept
    7200,      // 2 hours submit
    3600,      // 1 hour confirm
    { value: ethers.parseEther("0.1") }
);

// Time Breakdown:
// Hour 1: Seller sees and accepts
// Hour 1-3: Seller translates
// Hour 3-4: Buyer reviews
// Total: 4 hours max
```

**Characteristics:**
- ✅ Small scope, clear requirements
- ✅ Standard deliverables
- ✅ Quick verification
- ⚠️ Requires responsive seller

### 2. Short-Term Projects (1-7 days)

**Industries:**
- Logo design
- Social media graphics
- Blog articles
- Simple websites (landing pages)
- Video editing (short clips)

**Recommended Settings:**

```javascript
// Logo Design Project
await core.createDealETH(
    seller,
    termsHash,
    43200,     // 12 hours accept
    432000,    // 5 days submit (5 * 86400)
    172800,    // 2 days confirm
    { value: ethers.parseEther("2.0") }
);

// Time Breakdown:
// Day 1: Seller accepts (within 12h)
// Day 1-6: Design work (5 days)
// Day 6-8: Buyer reviews and provides feedback
// Total: ~8 days
```

**Characteristics:**
- ✅ Defined scope
- ✅ Some iteration expected
- ✅ Standard review process
- ⚠️ May need revision rounds

### 3. Medium-Term Projects (1-4 weeks)

**Industries:**
- Website development
- Mobile app (MVP)
- Brand identity package
- Video production
- Complex illustrations

**Recommended Settings:**

```javascript
// Website Development
await core.createDealETH(
    seller,
    termsHash,
    86400,      // 1 day accept
    1814400,    // 21 days submit (3 weeks)
    604800,     // 7 days confirm
    { value: ethers.parseEther("10.0") }
);

// Time Breakdown:
// Day 1: Seller accepts
// Day 1-22: Development (3 weeks)
// Day 22-29: Review, testing, minor fixes
// Total: ~29 days (1 month)
```

**Characteristics:**
- ✅ Multiple deliverable stages
- ✅ Iterative feedback
- ✅ Technical testing needed
- ⚠️ Requires clear milestones

### 4. Long-Term Projects (1-3 months)

**Industries:**
- Complex software development
- Large-scale design systems
- E-commerce platforms
- Mobile app (full featured)
- Architectural plans

**Recommended Settings:**

```javascript
// Full-Featured App Development
await core.createDealETH(
    seller,
    termsHash,
    259200,     // 3 days accept
    5184000,    // 60 days submit (2 months)
    1296000,    // 15 days confirm
    { value: ethers.parseEther("50.0") }
);

// Time Breakdown:
// Day 1-3: Seller reviews requirements, accepts
// Day 3-63: Development (2 months)
// Day 63-78: Testing, QA, minor fixes (2 weeks)
// Total: ~78 days (2.5 months)
```

**Characteristics:**
- ✅ Detailed specifications
- ✅ Milestone-based progress
- ✅ Extensive testing
- ⚠️ May need contract amendments

### 5. Supply Chain / Manufacturing (3-6 months)

**Industries:**
- Custom manufacturing
- Mold/tool production
- Hardware prototypes
- Physical product design
- International sourcing

**Recommended Settings:**

```javascript
// Custom Manufacturing Order
await core.createDealETH(
    seller,
    termsHash,
    604800,      // 7 days accept
    10368000,    // 120 days submit (4 months)
    1296000,     // 15 days confirm
    { value: ethers.parseEther("100.0") }
);

// Time Breakdown:
// Week 1: Seller evaluates feasibility, accepts
// Month 1-4: Production (120 days)
// Week 17-18: Inspection, quality check (15 days)
// Total: ~135 days (4.5 months)
```

**Characteristics:**
- ✅ Physical deliverables
- ✅ Production lead times
- ✅ Quality inspection required
- ⚠️ Consider shipping time

## Time Window Calculator

### Formula for Total Deal Duration

```
Total Duration = acceptWindow + submitWindow + confirmWindow

Example:
- Accept: 1 day (86400s)
- Submit: 14 days (1209600s)
- Confirm: 3 days (259200s)
- Total: 18 days (1555200s)
```

### Common Time Conversions

```javascript
// Time units in seconds
const HOUR = 3600;
const DAY = 86400;
const WEEK = 604800;
const MONTH = 2592000;  // 30 days

// Example usage
acceptWindow: 12 * HOUR,      // 12 hours
submitWindow: 14 * DAY,       // 14 days
confirmWindow: 3 * DAY        // 3 days
```

## Best Practices

### 1. Be Realistic

**Too Short:**
```javascript
// ❌ Bad: 1-hour website development
submitWindow: 3600  // Impossible!
```

**Too Long:**
```javascript
// ❌ Bad: 200 days for logo design
submitWindow: 17280000  // Exceeds MAX (also unreasonable)
```

**Just Right:**
```javascript
// ✅ Good: Reasonable for complexity
submitWindow: 432000  // 5 days for logo - appropriate
```

### 2. Consider Time Zones

If working with international sellers:

```javascript
// Add buffer for time zone differences
acceptWindow: 86400  // 1 day instead of 12 hours
// Seller might be sleeping when you create deal
```

### 3. Build in Buffer

```javascript
// Estimated work time: 10 days
// Set submit window: 14 days (40% buffer)
submitWindow: 1209600  // Allows for unexpected delays
```

### 4. Match Confirm to Complexity

| Project Complexity | Confirm Window | Reason |
|-------------------|----------------|--------|
| Simple | 1-2 days | Quick check |
| Medium | 3-7 days | Testing needed |
| Complex | 7-15 days | Thorough QA |

### 5. Plan for Disputes

The 24-hour dispute cooldown starts **after** work submission:

```
Timeline:
Day 14: Seller submits work
Day 14-15: Dispute cooldown (cannot raise dispute)
Day 15-17: Buyer can dispute if needed
Day 17: Auto-release if buyer doesn't confirm

Recommendation: Set confirmWindow > 3 days
```

## Common Scenarios

### Scenario 1: Rush Job

**Need:** Logo design in 48 hours

```javascript
await core.createDealETH(
    seller,
    termsHash,
    3600,       // 1 hour accept (urgent)
    86400,      // 1 day submit (24h rush)
    43200,      // 12 hours confirm (quick review)
    { value: ethers.parseEther("3.0") }  // Premium for rush
);
```

**Note:** Higher payment expected for rush jobs.

### Scenario 2: Ongoing Work

**Need:** Monthly content creation

```javascript
// Create NEW deal each month
// Don't try to use one deal for ongoing work

// Month 1
await core.createDealETH(seller, termsHash, ...);

// Month 2 (new deal)
await core.createDealETH(seller, termsHash, ...);
```

**Why:** Each deal is independent. Ongoing work needs multiple deals.

### Scenario 3: Uncertain Timeline

**Need:** Not sure how long work takes

```javascript
// Start conservatively
submitWindow: 2592000  // 30 days

// If seller delivers early:
// - Buyer can approve immediately
// - No need to wait full 30 days
```

**Principle:** Longer window is safer. Early delivery is always welcome.

### Scenario 4: High-Value Project

**Need:** $50K development project

```javascript
await core.createDealETH(
    seller,
    termsHash,
    604800,      // 7 days accept (careful evaluation)
    7776000,     // 90 days submit (3 months)
    1296000,     // 15 days confirm (thorough testing)
    { value: ethers.parseEther("50.0") }
);
```

**Additional:** Consider milestone-based payments (create multiple deals for phases).

## Limits & Constraints

### Hard Limits

```solidity
// From DealValidation.sol
MIN_ACCEPT_WINDOW = 1 hours      (3,600 seconds)
MAX_ACCEPT_WINDOW = 30 days      (2,592,000 seconds)

MIN_SUBMIT_WINDOW = 1 hours      (3,600 seconds)
MAX_SUBMIT_WINDOW = 180 days     (15,552,000 seconds)

MIN_CONFIRM_WINDOW = 1 hours     (3,600 seconds)
MAX_CONFIRM_WINDOW = 30 days     (2,592,000 seconds)
```

### Why These Limits?

**Minimums (1 hour):**
- Prevents instant-expiration attacks
- Gives reasonable time for blockchain confirmation
- Supports quick tasks (e.g., urgent translation)

**Maximums:**
- **180 days submit:** Supports supply chain (6 months production)
- **30 days accept/confirm:** Prevents indefinite fund locks
- Balances flexibility with security

### Projects Exceeding Limits

If your project needs > 180 days:

**Option 1: Break into Phases**
```javascript
// Phase 1: Design (60 days)
Deal #1: submitWindow = 5184000

// Phase 2: Prototype (90 days)
Deal #2: submitWindow = 7776000

// Phase 3: Production (90 days)
Deal #3: submitWindow = 7776000
```

**Option 2: Use Milestone Deals**
```javascript
// Each milestone = separate deal
// Reduces risk for both parties
// Better tracking of progress
```

## Testing Your Time Windows

### Frontend Helper Function

```javascript
function validateTimeWindows(accept, submit, confirm) {
    const HOUR = 3600;
    const DAY = 86400;
    
    const MIN_ACCEPT = HOUR;
    const MAX_ACCEPT = 30 * DAY;
    const MIN_SUBMIT = HOUR;
    const MAX_SUBMIT = 180 * DAY;
    const MIN_CONFIRM = HOUR;
    const MAX_CONFIRM = 30 * DAY;
    
    if (accept < MIN_ACCEPT || accept > MAX_ACCEPT) {
        throw new Error(`Accept window must be ${MIN_ACCEPT}-${MAX_ACCEPT}s`);
    }
    if (submit < MIN_SUBMIT || submit > MAX_SUBMIT) {
        throw new Error(`Submit window must be ${MIN_SUBMIT}-${MAX_SUBMIT}s`);
    }
    if (confirm < MIN_CONFIRM || confirm > MAX_CONFIRM) {
        throw new Error(`Confirm window must be ${MIN_CONFIRM}-${MAX_CONFIRM}s`);
    }
    
    return true;
}
```

### Time Preview Helper

```javascript
function previewTimeline(accept, submit, confirm) {
    const now = new Date();
    
    const acceptDeadline = new Date(now.getTime() + accept * 1000);
    const submitDeadline = new Date(acceptDeadline.getTime() + submit * 1000);
    const confirmDeadline = new Date(submitDeadline.getTime() + confirm * 1000);
    
    return {
        createdAt: now,
        acceptBy: acceptDeadline,
        submitBy: submitDeadline,
        confirmBy: confirmDeadline,
        totalDays: (confirm + submit + accept) / 86400
    };
}

// Usage
const timeline = previewTimeline(86400, 1209600, 259200);
console.log(`Total deal duration: ${timeline.totalDays} days`);
console.log(`Must accept by: ${timeline.acceptBy}`);
console.log(`Must submit by: ${timeline.submitBy}`);
console.log(`Must confirm by: ${timeline.confirmBy}`);
```

## Summary

### Key Takeaways

✅ **Flexible Ranges:** 1 hour to 180 days for delivery  
✅ **Industry-Specific:** Different defaults for different work types  
✅ **User-Controlled:** Buyers set timelines based on their needs  
✅ **Safety Bounds:** Limits prevent abuse and indefinite locks  
✅ **Early Completion:** No penalty for finishing before deadline  

### Quick Reference Table

| Task Type | Accept | Submit | Confirm | Total |
|-----------|--------|--------|---------|-------|
| Quick (translate) | 1h | 2h | 1h | 4h |
| Short (logo) | 12h | 5d | 2d | 7.5d |
| Medium (website) | 1d | 21d | 7d | 29d |
| Long (app) | 3d | 60d | 15d | 78d |
| Supply chain | 7d | 120d | 15d | 142d |

### Design Philosophy

> "Time windows should be **flexible enough** to accommodate diverse industries, yet **bounded enough** to prevent abuse. Buyers know their projects best and should have the freedom to set appropriate timelines."

This design makes YBZ suitable for:
- 🚀 Gig economy (quick tasks)
- 💼 Professional services (projects)
- 🏭 Manufacturing (long-term)
- 🌍 Global workforce (time zones)

---

**Version:** 1.0  
**Last Updated:** 2025-10-18  
**Status:** Implemented & Tested ✅

