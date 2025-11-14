# YBZ.io Deployment Guide

Complete step-by-step guide for deploying YBZ.io smart contracts.

---

## 📋 Prerequisites

### Software Requirements

- **Node.js**: v18.0.0 or higher
- **npm**: v9.0.0 or higher
- **Git**: v2.30.0 or higher
- **Hardhat**: Installed via npm

### Hardware Requirements

- **Minimum**: 4GB RAM, 10GB disk space
- **Recommended**: 8GB RAM, 20GB disk space
- **Network**: Stable internet connection for blockchain interaction

### Account Requirements

- Ethereum wallet with private key
- Sufficient ETH for deployment gas costs:
  - **Testnet**: ~0.1 ETH (free from faucet)
  - **Mainnet**: ~0.5 ETH (for deployment + buffer)

---

## 🔧 Setup

### 1. Clone and Install

```bash
# Clone repository
git clone https://github.com/your-org/ybz.git
cd ybz

# Install dependencies
npm install

# Verify installation
npx hardhat --version
```

### 2. Configure Environment

```bash
# Copy environment template
cp .env.example .env

# Edit configuration
nano .env
```

**Required Environment Variables**:

```env
# Deployer private key (NEVER share or commit!)
PRIVATE_KEY=0x1234...

# RPC endpoints
SEPOLIA_RPC_URL=https://eth-sepolia.g.alchemy.com/v2/YOUR_API_KEY
MAINNET_RPC_URL=https://eth-mainnet.g.alchemy.com/v2/YOUR_API_KEY

# Block explorer API keys (for verification)
ETHERSCAN_API_KEY=ABC123...

# Multi-sig treasury configuration
MULTISIG_APPROVER_1=0xABC...
MULTISIG_APPROVER_2=0xDEF...
MULTISIG_APPROVER_3=0x123...
MULTISIG_THRESHOLD=2

# Arbiter addresses
ARBITER_1=0x456...
ARBITER_2=0x789...

# Fee configuration
DEFAULT_PLATFORM_FEE_BPS=200  # 2%
DEFAULT_ARBITER_FEE_BPS=100   # 1%
```

### 3. Compile Contracts

```bash
# Clean and compile
npm run clean
npm run compile

# Expected output:
# Compiled 15 Solidity files successfully
```

### 4. Run Tests

```bash
# Run all tests
npm test

# Run with gas reporting
npm run test:gas

# Run with coverage
npm run coverage

# Expected: All tests passing, >95% coverage
```

---

## 🧪 Local Testing

### Start Local Node

```bash
# Terminal 1: Start Hardhat node
npx hardhat node

# Output shows:
# - 20 test accounts with 10,000 ETH each
# - Local RPC: http://127.0.0.1:8545
```

### Deploy to Local Node

```bash
# Terminal 2: Deploy contracts
npm run deploy:local

# Expected output:
# 🚀 Starting YBZ.io Platform Deployment...
# ✅ YBZFeeManager deployed to: 0x5FbDB...
# ✅ YBZTreasury deployed to: 0xe7f1...
# ✅ YBZArbitration deployed to: 0x9fE4...
# ✅ YBZCore deployed to: 0xCf7E...
# 🎉 Deployment Complete!
```

### Test Deployment

```bash
# Interact with contracts using Hardhat console
npx hardhat console --network localhost

# In console:
const YBZCore = await ethers.getContractFactory("YBZCore");
const core = await YBZCore.attach("0xCf7E...");
console.log(await core.version()); // "1.0.0"
```

---

## 🌐 Testnet Deployment (Sepolia)

### 1. Get Testnet ETH

Visit faucets to get test ETH:
- https://sepoliafaucet.com/
- https://faucet.quicknode.com/ethereum/sepolia

**Required**: ~0.1 ETH for deployment

### 2. Configure Testnet

Edit `hardhat.config.js`:

```javascript
sepolia: {
  url: process.env.SEPOLIA_RPC_URL,
  accounts: [process.env.PRIVATE_KEY],
  chainId: 11155111,
}
```

### 3. Deploy to Sepolia

```bash
# Deploy
npx hardhat run scripts/deploy.js --network sepolia

# Save deployment addresses from output
# Example output:
# YBZCore:        0x1234...
# YBZFeeManager:  0x5678...
# YBZTreasury:    0xABCD...
# YBZArbitration: 0xEF01...
```

### 4. Verify Contracts

```bash
# Verify Core contract
npx hardhat verify --network sepolia \
  <CORE_ADDRESS> \
  <ADMIN_ADDRESS> \
  <FEE_MANAGER_ADDRESS> \
  <TREASURY_ADDRESS> \
  <ARBITRATION_ADDRESS>

# Repeat for each contract
npx hardhat verify --network sepolia <FEE_MANAGER_ADDRESS> <ADMIN> 200 100
npx hardhat verify --network sepolia <TREASURY_ADDRESS> <ADMIN> "[<APPROVER1>,<APPROVER2>]" 2
npx hardhat verify --network sepolia <ARBITRATION_ADDRESS> <ADMIN> "[<ARBITER1>]"
```

### 5. Test on Sepolia

```javascript
// test-sepolia.js
const { ethers } = require("hardhat");

async function main() {
  const core = await ethers.getContractAt(
    "YBZCore",
    "0x1234..." // Your deployed address
  );

  // Create test deal
  const tx = await core.createDealETH(
    "0x5678...", // Seller address
    ethers.keccak256(ethers.toUtf8Bytes("Test terms")),
    86400,
    604800,
    259200,
    { value: ethers.parseEther("0.01") }
  );

  await tx.wait();
  console.log("Test deal created!");
}

main();
```

```bash
npx hardhat run test-sepolia.js --network sepolia
```

---

## 🚀 Mainnet Deployment

### Pre-Deployment Checklist

**Security & Testing**:
- [ ] ✅ All tests passing (100%)
- [ ] ✅ Coverage >95%
- [ ] ✅ 2+ independent security audits completed
- [ ] ✅ Bug bounty program run for 3+ months
- [ ] ✅ Testnet deployment tested for 1+ month

**Configuration**:
- [ ] ✅ Multi-sig wallet set up (Gnosis Safe recommended)
- [ ] ✅ All multi-sig signers verified
- [ ] ✅ Fee parameters reviewed and approved
- [ ] ✅ Initial arbiters vetted and approved

**Operations**:
- [ ] ✅ Monitoring system configured
- [ ] ✅ Alerting rules set up
- [ ] ✅ Incident response plan documented
- [ ] ✅ Emergency pause procedure tested
- [ ] ✅ Communication channels ready

**Legal & Compliance**:
- [ ] ✅ Legal review completed
- [ ] ✅ Terms of service finalized
- [ ] ✅ Privacy policy published
- [ ] ✅ Compliance requirements met
- [ ] ✅ Insurance coverage arranged (optional)

### Deployment Steps

#### Step 1: Final Configuration

```env
# .env for mainnet
PRIVATE_KEY=0x... # Use deployer key, not personal wallet
MAINNET_RPC_URL=https://eth-mainnet.g.alchemy.com/v2/...
ETHERSCAN_API_KEY=...

# Multi-sig treasury (Gnosis Safe)
MULTISIG_APPROVER_1=0x... # 5-7 trusted signers
MULTISIG_APPROVER_2=0x...
MULTISIG_APPROVER_3=0x...
MULTISIG_APPROVER_4=0x...
MULTISIG_APPROVER_5=0x...
MULTISIG_THRESHOLD=3      # Require 3-of-5

# Verified arbiters
ARBITER_1=0x... # KYC-verified arbiters
ARBITER_2=0x...
ARBITER_3=0x...

# Production fees
DEFAULT_PLATFORM_FEE_BPS=200  # 2%
DEFAULT_ARBITER_FEE_BPS=100   # 1%
```

#### Step 2: Test Deployment Locally First

```bash
# Simulate mainnet fork
npx hardhat node --fork https://eth-mainnet.g.alchemy.com/v2/...

# Deploy to fork
npm run deploy:local

# Test all functionality
```

#### Step 3: Deploy to Mainnet

```bash
# Ensure you have enough ETH (~0.5 ETH)
# Deploy contracts
npx hardhat run scripts/deploy.js --network mainnet

# ⚠️ SAVE ALL ADDRESSES IMMEDIATELY!
# Store in multiple secure locations
```

#### Step 4: Verify Contracts

```bash
# Verify all contracts on Etherscan
npx hardhat verify --network mainnet <CORE_ADDRESS> ...
npx hardhat verify --network mainnet <FEE_MANAGER_ADDRESS> ...
npx hardhat verify --network mainnet <TREASURY_ADDRESS> ...
npx hardhat verify --network mainnet <ARBITRATION_ADDRESS> ...

# Check verification status on Etherscan
```

#### Step 5: Transfer Admin to Multi-Sig

```javascript
// transfer-admin.js
const { ethers } = require("hardhat");

async function main() {
  const MULTISIG_ADDRESS = "0x..."; // Gnosis Safe
  
  const core = await ethers.getContractAt("YBZCore", CORE_ADDRESS);
  const feeManager = await ethers.getContractAt("YBZFeeManager", FEE_MANAGER_ADDRESS);
  const treasury = await ethers.getContractAt("YBZTreasury", TREASURY_ADDRESS);
  const arbitration = await ethers.getContractAt("YBZArbitration", ARBITRATION_ADDRESS);

  // Grant admin role to multi-sig
  const ADMIN_ROLE = await core.DEFAULT_ADMIN_ROLE();
  await core.grantRole(ADMIN_ROLE, MULTISIG_ADDRESS);
  await feeManager.grantRole(ADMIN_ROLE, MULTISIG_ADDRESS);
  await treasury.grantRole(ADMIN_ROLE, MULTISIG_ADDRESS);
  await arbitration.grantRole(ADMIN_ROLE, MULTISIG_ADDRESS);

  // Renounce deployer admin (irreversible!)
  console.log("⚠️  WARNING: About to renounce admin role!");
  console.log("Press Ctrl+C to cancel, or wait 10 seconds...");
  await new Promise(r => setTimeout(r, 10000));

  await core.renounceRole(ADMIN_ROLE, deployer.address);
  await feeManager.renounceRole(ADMIN_ROLE, deployer.address);
  await treasury.renounceRole(ADMIN_ROLE, deployer.address);
  await arbitration.renounceRole(ADMIN_ROLE, deployer.address);

  console.log("✅ Admin transferred to multi-sig");
}

main();
```

```bash
# Execute transfer (IRREVERSIBLE!)
npx hardhat run transfer-admin.js --network mainnet
```

#### Step 6: Configure Monitoring

```bash
# Set up Tenderly monitoring
npm install --save-dev @tenderly/hardhat-tenderly
npx hardhat tenderly:verify YBZCore=<ADDRESS>

# Configure alerts for:
# - Contract paused
# - Large withdrawals
# - Failed transactions
# - Unusual activity
```

#### Step 7: Whitelist Tokens

```javascript
// Configure accepted tokens (via multi-sig)
const USDT = "0xdAC17F958D2ee523a2206206994597C13D831ec7";
const USDC = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48";
const DAI = "0x6B175474E89094C44Da98b954EedeAC495271d0F";

// Via Gnosis Safe, call:
await core.whitelistToken(USDT);
await core.whitelistToken(USDC);
await core.whitelistToken(DAI);
```

---

## 📊 Post-Deployment

### Verification Checklist

- [ ] All contracts verified on Etherscan
- [ ] Multi-sig is the only admin
- [ ] Deployer has no admin rights
- [ ] All expected tokens whitelisted
- [ ] Fee parameters correct
- [ ] Arbiters registered and active
- [ ] Monitoring and alerts configured
- [ ] Documentation updated with addresses

### Announcement

Prepare deployment announcement:

```markdown
# YBZ.io Mainnet Launch 🚀

We're excited to announce YBZ.io is now live on Ethereum mainnet!

**Contract Addresses:**
- YBZCore: 0x...
- YBZFeeManager: 0x...
- YBZTreasury: 0x...
- YBZArbitration: 0x...

**Security:**
- Audited by [Audit Firm 1] and [Audit Firm 2]
- Bug bounty: $100k pool
- Multi-sig governance: 3-of-5

**Get Started:**
Visit https://ybz.io to create your first escrow deal!
```

---

## 🔄 Upgrade Process

### When to Upgrade

- Critical bug fixes
- Security improvements
- New features approved by governance
- Gas optimizations

### Upgrade Steps

```bash
# 1. Deploy new implementation
npx hardhat run scripts/deploy-v2.js --network mainnet

# 2. Via multi-sig, propose upgrade
# Call: upgradeTo(newImplementationAddress)

# 3. Multi-sig approves (3-of-5)

# 4. Execute upgrade

# 5. Verify state integrity
npx hardhat run scripts/verify-state.js --network mainnet

# 6. Monitor for issues
```

---

## 🆘 Emergency Procedures

### If Critical Bug Found

1. **Pause Contract**
   ```javascript
   // Via multi-sig
   await core.pause();
   ```

2. **Assess Impact**
   - Identify affected deals
   - Calculate potential losses

3. **Communicate**
   - Notify users immediately
   - Post on Twitter, Discord, website

4. **Fix & Upgrade**
   - Deploy patched version
   - Upgrade via UUPS
   - Resume operations

### If Funds at Risk

1. **Immediate pause** (if possible)
2. **Contact security team**
3. **Freeze affected functions**
4. **Coordinate with affected users**
5. **Execute recovery plan**

---

## 📞 Support

For deployment support:
- **Email**: devops@ybz.io
- **Discord**: https://discord.gg/ybz
- **Documentation**: https://docs.ybz.io

---

**Last Updated**: 2025-10-17  
**Version**: 1.0.0

