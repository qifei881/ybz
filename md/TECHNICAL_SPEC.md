# YBZ.io Technical Specification

## 📐 Contract Architecture

### Core Contracts

#### 1. YBZCore.sol (Main Contract)

**Purpose**: Central escrow logic and state management

**Key Features**:
- UUPS upgradeable proxy pattern
- Multi-token support (ETH + whitelisted ERC20)
- 8-state finite state machine
- Automatic timeout execution
- Integrated dispute resolution
- Reentrancy protection
- Pausable for emergencies

**State Machine**:
```solidity
enum DealStatus {
    Created,      // 0: Deal created, awaiting seller acceptance
    Accepted,     // 1: Seller accepted, work in progress
    Submitted,    // 2: Work submitted, awaiting buyer confirmation
    Disputed,     // 3: Dispute raised, arbitration in progress
    Approved,     // 4: Deal approved, funds released
    Cancelled,    // 5: Deal cancelled due to timeout
    Resolved,     // 6: Dispute resolved by arbiter
    Closed        // 7: Deal closed and storage cleaned
}
```

**Functions**:

| Function | Caller | State Change | Description |
|----------|--------|--------------|-------------|
| `createDealETH()` | Buyer | → Created | Creates ETH escrow |
| `createDealERC20()` | Buyer | → Created | Creates ERC20 escrow |
| `acceptDeal()` | Seller | Created → Accepted | Seller accepts work |
| `submitWork()` | Seller | Accepted → Submitted | Submits delivery |
| `approveDeal()` | Buyer | Submitted → Approved | Releases payment |
| `raiseDispute()` | Buyer/Seller | → Disputed | Initiates arbitration |
| `resolveDispute()` | Arbiter | Disputed → Resolved | Resolves dispute |
| `cancelDeal()` | Anyone | → Cancelled | Cancels if timeout |
| `autoRefund()` | Buyer | Accepted → Cancelled | Refund after submit timeout |
| `autoRelease()` | Anyone | Submitted → Approved | Release after confirm timeout |

**Time Control**:
```solidity
uint64 acceptDeadline;      // Seller must accept before this
uint64 submitDeadline;      // Seller must submit before this
uint64 confirmDeadline;     // Buyer must confirm before this
```

**Gas Optimization**:
- Storage variable packing (saves ~20k gas per deal)
- Batch operations where possible
- Event-based state tracking
- Optional storage cleanup on close

---

#### 2. YBZFeeManager.sol

**Purpose**: Dynamic fee calculation and management

**Features**:
- Configurable platform and arbiter fees
- Tiered pricing based on transaction size
- Min/max fee caps
- Governance-controlled parameters

**Fee Structure**:
```solidity
struct FeeStructure {
    uint16 platformFeeBps;              // Default platform fee (200 = 2%)
    uint16 arbiterFeeBps;               // Arbiter fee (100 = 1%)
    uint256 minFee;                     // Minimum fee amount
    uint256 maxFee;                     // Maximum fee cap
    mapping(uint256 => uint16) tieredRates; // Amount threshold => fee bps
}
```

**Example Tier Configuration**:
```javascript
// Tier 1: < 1 ETH = 2%
// Tier 2: 1-10 ETH = 1.5%
// Tier 3: 10-100 ETH = 1%
// Tier 4: > 100 ETH = 0.5%
```

**Admin Functions**:
- `updatePlatformFee()`: Update default platform fee
- `updateArbiterFee()`: Update arbiter fee
- `addTier()`: Add new pricing tier
- `removeTier()`: Remove pricing tier

---

#### 3. YBZTreasury.sol

**Purpose**: Multi-signature treasury for platform fees

**Features**:
- Multi-sig withdrawal approval workflow
- Proposal-based withdrawals
- Time-limited proposals (7 days)
- Support for ETH and ERC20
- Transparent on-chain tracking

**Withdrawal Flow**:
```
1. Approver proposes withdrawal
   ├─ Creates proposal with details
   └─ Auto-approves from proposer

2. Other approvers vote
   └─ threshold approvals required

3. Anyone executes if approved
   ├─ Transfers funds
   └─ Marks proposal as executed
```

**Proposal Structure**:
```solidity
struct WithdrawalProposal {
    address token;          // Token to withdraw (address(0) for ETH)
    address to;             // Recipient address
    uint256 amount;         // Amount to withdraw
    uint8 approvals;        // Current approval count
    mapping(address => bool) hasApproved; // Who has approved
    bool executed;          // Execution status
    uint64 proposedAt;      // Proposal timestamp
}
```

---

#### 4. YBZArbitration.sol

**Purpose**: Dispute resolution and arbiter management

**Features**:
- Arbiter registry with reputation system
- Single and multi-sig arbitration modes
- Evidence submission (IPFS hashes)
- Flexible fund allocation (0-100% split)
- Arbiter performance tracking

**Arbiter Information**:
```solidity
struct ArbiterInfo {
    bool isActive;          // Active status
    uint256 totalCases;     // Total cases assigned
    uint256 resolvedCases;  // Successfully resolved
    uint256 reputation;     // Score 0-100
    uint64 registeredAt;    // Registration timestamp
}
```

**Dispute Resolution**:
```solidity
// Single Arbiter Mode
resolveDispute(dealId, 60, 40, evidenceHash);
// 60% to buyer, 40% to seller

// Multi-Sig Mode (3 arbiters, 2 required)
initMultiSigArbitration(dealId, [arbiter1, arbiter2, arbiter3], 2);
arbiter1.voteMultiSig(dealId, 70, 30, evidence);
arbiter2.voteMultiSig(dealId, 50, 50, evidence);
// Average: 60% buyer, 40% seller
```

---

### Supporting Contracts

#### DealValidation.sol (Library)

**Purpose**: Gas-efficient validation logic

**Constants**:
```solidity
uint64 MIN_ACCEPT_WINDOW = 1 hours;
uint64 MIN_SUBMIT_WINDOW = 1 days;
uint64 MIN_CONFIRM_WINDOW = 1 days;
uint64 MAX_ACCEPT_WINDOW = 30 days;
uint64 MAX_SUBMIT_WINDOW = 90 days;
uint64 MAX_CONFIRM_WINDOW = 30 days;
uint256 MIN_DEAL_AMOUNT = 0.001 ether;
```

**Functions**:
- `validateCreateDeal()`: Validates deal creation parameters
- `requireStatus()`: Checks current state
- `requireAuthorized()`: Validates caller permissions
- `requireDeadlinePassed()`: Checks if deadline expired
- `canCancel()`: Checks if deal can be cancelled
- `canAutoRelease()`: Checks if auto-release is allowed

---

#### IYBZCore.sol (Interface)

**Purpose**: Standard interface for core functionality

Defines:
- All public structs (Deal, DisputeResolution)
- All events
- All external function signatures

---

## 🔒 Security Model

### Access Control Roles

| Role | Permissions | Default Holder |
|------|-------------|----------------|
| `DEFAULT_ADMIN_ROLE` | Grant/revoke roles, pause, upgrade | Deployer |
| `UPGRADER_ROLE` | Authorize contract upgrades | Deployer |
| `OPERATOR_ROLE` | Override dispute resolution | Deployer |
| `TREASURY_ROLE` | Deposit fees to treasury | Core contract |
| `WITHDRAWAL_ROLE` | Propose/approve withdrawals | Multi-sig |
| `ARBITER_ROLE` | Resolve disputes | Registered arbiters |
| `FEE_ADMIN_ROLE` | Update fee parameters | Admin |

### Attack Vectors & Mitigations

#### 1. Reentrancy Attack
**Risk**: Malicious contract drains funds during callback

**Mitigation**:
- `nonReentrant` modifier on all fund transfers
- Checks-Effects-Interactions pattern
- State updates before external calls

```solidity
function approveDeal(uint256 dealId) external nonReentrant {
    // 1. Checks
    require(deal.status == DealStatus.Submitted);
    
    // 2. Effects
    deal.status = DealStatus.Approved;
    
    // 3. Interactions
    _releaseFunds(dealId);
}
```

#### 2. Front-Running
**Risk**: Arbiters front-run resolution to benefit one party

**Mitigation** (Future):
- Commit-reveal scheme for dispute resolution
- Time-locked resolution proposals
- Multi-sig arbitration reduces single-point manipulation

#### 3. Timestamp Manipulation
**Risk**: Miners manipulate `block.timestamp` by ~15 seconds

**Mitigation**:
- Use long time windows (hours/days)
- Combine with block number checks for critical operations
- 15-second variance negligible for day-long deadlines

#### 4. Integer Overflow/Underflow
**Risk**: Arithmetic errors in fee calculations

**Mitigation**:
- Solidity 0.8.x has built-in overflow protection
- Explicit bounds checking in validation library
- Max fee caps prevent excessive calculations

#### 5. Denial of Service
**Risk**: Griefing by creating many deals

**Mitigation**:
- Minimum deal amount (0.001 ETH)
- Gas-optimized operations
- Optional storage cleanup

---

## 💰 Economic Model

### Fee Distribution

**Normal Deal (No Dispute)**:
```
Deal Amount: 1.00 ETH
├─ Platform Fee (2%): 0.02 ETH → Treasury
└─ Seller Receives: 0.98 ETH
```

**Disputed Deal**:
```
Deal Amount: 1.00 ETH
├─ Platform Fee (2%): 0.02 ETH → Treasury
├─ Arbiter Fee (1%): 0.01 ETH → Arbiter
└─ Net Amount: 0.97 ETH
    ├─ Buyer Share (60%): 0.582 ETH
    └─ Seller Share (40%): 0.388 ETH
```

### Treasury Revenue Model

**Revenue Sources**:
1. Platform fees from all deals (2%)
2. Arbiter fees retained if dispute self-resolves

**Revenue Distribution** (Future DAO):
- 50% → Protocol development
- 30% → Security audits & insurance fund
- 20% → Token buyback & burn

---

## ⛽ Gas Costs

**Estimated Gas Usage** (Sepolia testnet):

| Operation | Gas Cost | ETH (20 gwei) | USD ($2000/ETH) |
|-----------|----------|---------------|-----------------|
| Create Deal (ETH) | ~150,000 | 0.003 ETH | $6.00 |
| Accept Deal | ~50,000 | 0.001 ETH | $2.00 |
| Submit Work | ~55,000 | 0.0011 ETH | $2.20 |
| Approve Deal | ~120,000 | 0.0024 ETH | $4.80 |
| Raise Dispute | ~80,000 | 0.0016 ETH | $3.20 |
| Resolve Dispute | ~140,000 | 0.0028 ETH | $5.60 |
| Cancel Deal | ~70,000 | 0.0014 ETH | $2.80 |

**Total Happy Path**: ~375k gas (~$15 at $2000 ETH)

---

## 🧪 Testing Strategy

### Unit Tests (test/YBZCore.test.js)

**Coverage Areas**:
1. ✅ Deployment and initialization
2. ✅ Deal creation (ETH + ERC20)
3. ✅ State transitions (all paths)
4. ✅ Happy path (full lifecycle)
5. ✅ Timeout scenarios
6. ✅ Dispute resolution
7. ✅ Fee calculations
8. ✅ Access control
9. ✅ Edge cases
10. ✅ Multiple simultaneous deals

**Test Coverage Target**: >95%

### Integration Tests (Planned)

- Multi-contract interaction flows
- Upgrade scenarios
- Treasury withdrawal flows
- Multi-sig arbitration

### Fuzzing (Planned)

Using Foundry/Echidna:
- Random input generation
- State machine invariants
- Arithmetic overflow checks

---

## 🚀 Deployment Process

### 1. Pre-Deployment

```bash
# Install dependencies
npm install

# Compile contracts
npm run compile

# Run tests
npm test

# Check coverage
npm run coverage

# Gas profiling
npm run test:gas
```

### 2. Testnet Deployment

```bash
# Configure .env
cp .env.example .env
nano .env

# Deploy to Sepolia
npm run deploy:testnet

# Verify contracts
npx hardhat verify --network sepolia <CONTRACT_ADDRESS>
```

### 3. Mainnet Preparation

**Checklist**:
- [ ] Complete 2+ independent security audits
- [ ] Run bug bounty program (3-6 months)
- [ ] Test all functionality on testnet
- [ ] Set up multi-sig treasury (3-of-5 or 4-of-7)
- [ ] Configure monitoring & alerting
- [ ] Prepare incident response plan
- [ ] Legal review and compliance check
- [ ] Insurance coverage for smart contract risks

### 4. Mainnet Deployment

```bash
# Final checks
npm run test
npm run coverage

# Deploy
npm run deploy:mainnet

# Verify
npm run verify

# Transfer admin to multi-sig
# (Critical: do this after deployment)
```

---

## 🔧 Upgrade Process (UUPS)

### Upgrade Flow

```
1. Deploy new implementation contract
2. Multi-sig proposes upgrade
3. Governance votes on upgrade
4. Execute upgrade via proxy
5. Verify state migration
```

### Storage Layout

**Critical**: New versions must maintain storage layout:

```solidity
// Slot 0-50: Reserved by OpenZeppelin upgradeable contracts
// Slot 51: _dealIdCounter
// Slot 52+: _deals mapping
// Slot X+: _resolutions mapping
```

**Safe Operations**:
- ✅ Add new functions
- ✅ Add new state variables at end
- ✅ Modify function logic

**Unsafe Operations**:
- ❌ Reorder state variables
- ❌ Change variable types
- ❌ Delete state variables
- ❌ Inherit from new contracts

---

## 📊 Monitoring & Analytics

### Key Metrics

**On-Chain Events to Track**:
- `DealCreated`: Total volume, deal count
- `DealApproved`: Success rate
- `DisputeRaised`: Dispute rate
- `DisputeResolved`: Arbiter performance
- `DealCancelled`: Cancellation reasons

**Health Indicators**:
- Success rate (approved / total)
- Dispute rate (disputed / total)
- Average deal size
- Average completion time
- Platform fee revenue

### Alerting Rules

**Critical Alerts**:
- Contract paused
- Large withdrawal from treasury
- Unusually high dispute rate (>10%)
- Failed transactions spike

**Warning Alerts**:
- Low arbiter availability
- Treasury balance low
- Gas prices spiking

---

## 🌐 Frontend Integration

### Recommended Stack

- **Framework**: Next.js or Vue 3
- **Web3 Library**: ethers.js v6 or viem
- **Wallet**: RainbowKit or wagmi
- **Storage**: IPFS (Pinata/Web3.Storage)
- **Backend**: Node.js (optional, for indexing)

### Example Integration

```javascript
import { ethers } from 'ethers';
import YBZCoreABI from './abis/YBZCore.json';

const provider = new ethers.BrowserProvider(window.ethereum);
const signer = await provider.getSigner();

const ybzCore = new ethers.Contract(
  YBZ_CORE_ADDRESS,
  YBZCoreABI,
  signer
);

// Create deal
const tx = await ybzCore.createDealETH(
  sellerAddress,
  termsHash,
  86400,
  604800,
  259200,
  { value: ethers.parseEther("1.0") }
);

await tx.wait();
console.log("Deal created!");
```

---

## 📚 API Reference

See [API.md](./docs/API.md) for complete function signatures and parameters.

---

## 🔗 External Dependencies

### Smart Contract Dependencies

```json
{
  "@openzeppelin/contracts-upgradeable": "^5.0.1",
  "@openzeppelin/contracts": "^5.0.1"
}
```

**Used Modules**:
- `Initializable`: Proxy initialization
- `UUPSUpgradeable`: Upgrade mechanism
- `AccessControlUpgradeable`: Role-based access
- `ReentrancyGuardUpgradeable`: Reentrancy protection
- `PausableUpgradeable`: Emergency pause
- `SafeERC20`: Safe token transfers

---

## 📖 Further Reading

- [Solidity Style Guide](https://docs.soliditylang.org/en/latest/style-guide.html)
- [OpenZeppelin Contracts](https://docs.openzeppelin.com/contracts/)
- [Hardhat Documentation](https://hardhat.org/docs)
- [EIP-1967: Proxy Storage Slots](https://eips.ethereum.org/EIPS/eip-1967)
- [EIP-1822: UUPS Proxies](https://eips.ethereum.org/EIPS/eip-1822)

---

**Document Version**: 1.0.0  
**Last Updated**: 2025-10-17  
**Maintained By**: YBZ.io Team

