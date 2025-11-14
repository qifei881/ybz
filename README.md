# YBZ.io - Decentralized Escrow Platform

Contract
https://etherscan.io/address/0xfb3dea227fe53d6999c6933a07b57a64075ca77d

> **"Trustless. Transparent. Guaranteed."**

YBZ.io is a blockchain-based smart escrow platform that enables trustless transactions between parties through automated smart contracts. Think of it as the "Web3 PayPal Escrow" - providing secure transaction guarantees without centralized intermediaries.

---

## 📋 Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Architecture](#architecture)
- [Smart Contracts](#smart-contracts)
- [Getting Started](#getting-started)
- [Usage Examples](#usage-examples)
- [Testing](#testing)
- [Deployment](#deployment)
- [Security](#security)
- [Roadmap](#roadmap)
- [Contributing](#contributing)
- [License](#license)

---

## 🎯 Overview

YBZ.io solves the trust problem in decentralized transactions by:

- **Locking funds** in smart contracts until conditions are met
- **Automating** payments based on predefined deadlines
- **Providing** dispute resolution through arbitration
- **Ensuring** transparency with on-chain event logging
- **Eliminating** reliance on centralized intermediaries

### Use Cases

- 🎨 **Freelance Work**: Developers, designers, consultants
- 🛍️ **Digital Goods**: NFTs, source code, digital assets
- 🤝 **B2B Transactions**: Cross-border business deals
- 🏗️ **DAO Tasks**: Bounties and milestone-based payments

---

## ✨ Features

### Core Functionality

✅ **Multi-Currency Support**: ETH and whitelisted ERC20 tokens  
✅ **Automated Execution**: Time-based automatic release/refund  
✅ **Flexible Deadlines**: Customizable time windows for each stage  
✅ **Dispute Resolution**: Built-in arbitration system  
✅ **Dynamic Fees**: Tiered fee structure based on transaction size  
✅ **Multi-Sig Treasury**: Secure platform fee management  
✅ **Upgradeable**: UUPS proxy pattern for future improvements  

### Security Features

🔒 **ReentrancyGuard**: Protection against reentrancy attacks  
🔒 **Pausable**: Emergency stop mechanism  
🔒 **Access Control**: Role-based permissions  
🔒 **Audit Trail**: Complete on-chain event logging  
🔒 **Gas Optimized**: Efficient storage patterns  

---

## 🏗️ Architecture

```
┌──────────────────────────────────────────┐
│              Frontend DApp               │
│         (Vue3 + ethers.js)               │
└──────────────────────────────────────────┘
                    │
                    ▼
┌──────────────────────────────────────────┐
│              YBZCore (Main)              │
│  - Deal Creation & Management            │
│  - State Machine Logic                   │
│  - Fund Custody & Distribution           │
└──────────────────────────────────────────┘
          │          │          │
    ┌─────┴────┬────┴────┬─────┴─────┐
    ▼          ▼         ▼           ▼
┌────────┐ ┌────────┐ ┌───────┐ ┌────────┐
│  Fee   │ │Treasury│ │Arbiter│ │Libraries│
│Manager │ │        │ │       │ │        │
└────────┘ └────────┘ └───────┘ └────────┘
```

### Contract Hierarchy

```
YBZCore (main escrow logic)
├── YBZFeeManager (fee calculations)
├── YBZTreasury (multi-sig withdrawals)
├── YBZArbitration (dispute resolution)
└── Libraries
    ├── DealValidation (validation logic)
    └── IYBZCore (interface definitions)
```

---

## 📜 Smart Contracts

### YBZCore.sol

Main escrow contract implementing the complete deal lifecycle:

- **Deal Creation**: ETH and ERC20 escrow
- **State Management**: 8-state FSM (Finite State Machine)
- **Automatic Execution**: Timeout-based actions
- **Fund Distribution**: Multi-party splits with fees

### YBZFeeManager.sol

Dynamic fee structure management:

- Configurable platform and arbiter fees
- Tiered pricing based on transaction volume
- Min/max fee caps
- Governance-controlled updates

### YBZTreasury.sol

Multi-signature treasury for platform revenue:

- Multi-sig approval workflow
- Transparent withdrawal proposals
- Role-based access control
- ETH and ERC20 support

### YBZArbitration.sol

Dispute resolution system:

- Arbiter registry and reputation
- Single and multi-sig arbitration
- Evidence submission (IPFS hashes)
- Flexible fund allocation

---

## 🚀 Getting Started

### Prerequisites

- Node.js v18+ and npm
- Hardhat development environment
- MetaMask or compatible Web3 wallet

### Installation

```bash
# Clone the repository
git clone https://github.com/your-org/ybz.git
cd ybz

# Install dependencies
npm install

# Copy environment template
cp .env.example .env

# Edit .env with your configuration
nano .env
```

### Configuration

Edit `.env` file:

```env
# Admin and deployer keys (NEVER commit real keys!)
PRIVATE_KEY=your_private_key_here

# RPC endpoints
SEPOLIA_RPC_URL=https://eth-sepolia.g.alchemy.com/v2/YOUR_KEY

# Multi-sig treasury
MULTISIG_APPROVER_1=0x...
MULTISIG_THRESHOLD=2

# Fee configuration
DEFAULT_PLATFORM_FEE_BPS=200  # 2%
DEFAULT_ARBITER_FEE_BPS=100   # 1%
```

### Compile Contracts

```bash
npm run compile
```

---

## 📖 Usage Examples

### Creating an Escrow Deal (ETH)

```javascript
const termsHash = ethers.keccak256(ethers.toUtf8Bytes("Project deliverables..."));

const tx = await ybzCore.createDealETH(
  sellerAddress,
  termsHash,
  86400,    // 1 day for seller to accept
  604800,   // 7 days for work submission
  259200,   // 3 days for buyer confirmation
  { value: ethers.parseEther("1.0") }
);

const receipt = await tx.wait();
const dealId = receipt.logs[0].args.dealId;
console.log("Deal created:", dealId);
```

### Seller Accepts Deal

```javascript
await ybzCore.connect(seller).acceptDeal(dealId);
console.log("Deal accepted");
```

### Seller Submits Work

```javascript
const deliveryHash = ethers.keccak256(ethers.toUtf8Bytes("IPFS_CID_here"));
await ybzCore.connect(seller).submitWork(dealId, deliveryHash);
console.log("Work submitted");
```

### Buyer Approves

```javascript
await ybzCore.connect(buyer).approveDeal(dealId);
console.log("Payment released");
```

### Raising a Dispute

```javascript
const evidenceHash = ethers.keccak256(ethers.toUtf8Bytes("Evidence details..."));
await ybzCore.connect(buyer).raiseDispute(dealId, evidenceHash);
console.log("Dispute raised");
```

### Arbiter Resolves Dispute

```javascript
// 60% to buyer, 40% to seller
await ybzCore.connect(arbiter).resolveDispute(
  dealId,
  60,
  40,
  evidenceHash
);
console.log("Dispute resolved");
```

---

## 🧪 Testing

### Run All Tests

```bash
npm test
```

### Run with Coverage

```bash
npm run coverage
```

### Run with Gas Reporter

```bash
npm run test:gas
```

### Test Results Expected

```
YBZCore
  ✓ Deployment and initialization
  ✓ Deal creation (ETH and ERC20)
  ✓ State transitions (happy path)
  ✓ Timeout scenarios
  ✓ Dispute resolution
  ✓ Fee calculations
  ✓ Access control
  ✓ Edge cases

Test Coverage: >95%
```

---

## 🌐 Deployment

### Local Testnet

```bash
# Terminal 1: Start local node
npm run node

# Terminal 2: Deploy contracts
npm run deploy:local
```

### Testnet (Sepolia)

```bash
# Configure .env with testnet RPC and private key
npm run deploy:testnet
```

### Mainnet Deployment

⚠️ **Pre-deployment Checklist**:

1. ✅ Complete security audit
2. ✅ Test all functionality on testnet
3. ✅ Configure multi-sig treasury
4. ✅ Set up monitoring and alerting
5. ✅ Prepare emergency pause procedure
6. ✅ Verify contract on block explorer

```bash
npm run deploy:mainnet
npm run verify -- <CONTRACT_ADDRESS>
```

---

## 🔒 Security

### Security Measures

- **ReentrancyGuard**: All fund transfer functions
- **Access Control**: Role-based permissions (OpenZeppelin)
- **Pausable**: Emergency stop for critical situations
- **Upgradeable**: UUPS pattern with admin controls
- **Event Logging**: Complete audit trail on-chain
- **Input Validation**: Comprehensive checks via DealValidation library

### Known Limitations

⚠️ **Arbiter Selection**: Current implementation uses pseudo-random selection. For production, integrate Chainlink VRF.

⚠️ **Gas Costs**: Complex deals with disputes have higher gas costs.

### Security Audits

- [ ] **Pending**: CertiK audit
- [ ] **Pending**: SlowMist audit
- [ ] **Planned**: Bug bounty program

### Reporting Vulnerabilities

Please report security issues to: **security@ybz.io**

Do NOT open public issues for security vulnerabilities.

---

## 📝 State Machine

```
Created ──accept──> Accepted ──submit──> Submitted ──approve──> Approved ──> Closed
   │                   │                      │                      │
   │                   │                      │                      │
   └──timeout──> Cancelled              Disputed <──dispute──────────┘
                                             │
                                             │
                                        resolve
                                             │
                                             ▼
                                        Resolved ──> Closed
```

### State Transitions

| State     | Trigger              | Next State |
|-----------|----------------------|------------|
| Created   | `acceptDeal()`       | Accepted   |
| Created   | Timeout              | Cancelled  |
| Accepted  | `submitWork()`       | Submitted  |
| Accepted  | Timeout              | Cancelled  |
| Submitted | `approveDeal()`      | Approved   |
| Submitted | `raiseDispute()`     | Disputed   |
| Submitted | Timeout              | Approved   |
| Disputed  | `resolveDispute()`   | Resolved   |
| Approved  | Auto                 | Closed     |
| Resolved  | Auto                 | Closed     |

---

## 💰 Fee Structure

### Default Fees

- **Platform Fee**: 2% (200 basis points)
- **Arbiter Fee**: 1% (only charged if disputed)

### Tiered Pricing (Configurable)

| Transaction Amount | Platform Fee |
|-------------------|--------------|
| < 1 ETH           | 2%           |
| 1-10 ETH          | 1.5%         |
| 10-100 ETH        | 1%           |
| > 100 ETH         | 0.5%         |

Fees can be adjusted via governance.

---

## 🗺️ Roadmap

### Phase 1: MVP ✅

- [x] Core escrow logic
- [x] Multi-currency support (ETH + ERC20)
- [x] Dispute resolution
- [x] Multi-sig treasury
- [x] Comprehensive tests

### Phase 2: Mainnet Launch (Q3 2025)

- [ ] Security audits (2+ firms)
- [ ] Testnet deployment and testing
- [ ] Bug bounty program
- [ ] Mainnet deployment
- [ ] Basic frontend DApp

### Phase 3: Feature Expansion (Q4 2025)

- [ ] Chainlink VRF for arbiter selection
- [ ] Reputation system for arbiters
- [ ] IPFS integration for terms/evidence
- [ ] Mobile app (React Native)

### Phase 4: Scaling (2026)

- [ ] Layer 2 deployment (Polygon, Arbitrum)
- [ ] Cross-chain bridges
- [ ] Advanced dispute resolution (multi-sig)
- [ ] API for third-party integrations

### Phase 5: Decentralization (2026+)

- [ ] DAO governance launch
- [ ] Community arbiter onboarding
- [ ] Protocol fee distribution
- [ ] Full decentralization

---

## 🤝 Contributing

We welcome contributions! Please follow these steps:

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/amazing-feature`
3. Commit your changes: `git commit -m 'Add amazing feature'`
4. Push to the branch: `git push origin feature/amazing-feature`
5. Open a Pull Request

### Development Guidelines

- Write comprehensive tests for new features
- Follow Solidity style guide
- Add NatSpec comments to all functions
- Ensure all tests pass before submitting PR
- Update documentation as needed

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 📞 Contact

- **Website**: https://ybz.io
- **Email**: hello@ybz.io
- **Twitter**: @YBZ_io
- **Discord**: [Join our community](https://discord.gg/ybz)

---

## 🙏 Acknowledgments

- OpenZeppelin for security contracts
- Hardhat for development tools
- Ethereum community for standards and best practices

---

<p align="center">
  <strong>Built with ❤️ by the YBZ.io Team</strong>
</p>

<p align="center">
  <em>"Trustless. Transparent. Guaranteed."</em>
</p>

