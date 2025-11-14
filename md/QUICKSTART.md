# YBZ.io Quick Start Guide

Get up and running with YBZ.io in 5 minutes!

---

## ⚡ Quick Setup

### 1. Install Dependencies (1 minute)

```bash
cd ybz
npm install
```

### 2. Compile Contracts (30 seconds)

```bash
npm run compile
```

Expected output:
```
Compiled 15 Solidity files successfully
```

### 3. Run Tests (2 minutes)

```bash
npm test
```

Expected output:
```
  YBZCore
    ✓ Deployment (150ms)
    ✓ Deal creation (ETH) (200ms)
    ✓ Happy path workflow (500ms)
    ... 20+ more tests

  25 passing (5s)
```

---

## 🚀 Deploy Locally (1 minute)

### Terminal 1: Start Node

```bash
npx hardhat node
```

### Terminal 2: Deploy

```bash
npm run deploy:local
```

You'll see:
```
🚀 Starting YBZ.io Platform Deployment...
✅ YBZCore deployed to: 0x5FbDB2315678afecb367f032d93F642f64180aa3
🎉 Deployment Complete!
```

---

## 💡 Usage Example

### Create Your First Deal

```javascript
// test-deal.js
const { ethers } = require("hardhat");

async function main() {
  const [buyer, seller] = await ethers.getSigners();
  
  // Get deployed contract
  const core = await ethers.getContractAt(
    "YBZCore",
    "0x5FbDB2315678afecb367f032d93F642f64180aa3" // From deployment
  );

  // Create deal
  const termsHash = ethers.keccak256(ethers.toUtf8Bytes("Build a website"));
  
  const tx = await core.connect(buyer).createDealETH(
    seller.address,
    termsHash,
    86400,    // 1 day to accept
    604800,   // 7 days to complete
    259200,   // 3 days to confirm
    { value: ethers.parseEther("1.0") }
  );

  const receipt = await tx.wait();
  console.log("✅ Deal created! Transaction:", receipt.hash);
  
  // Seller accepts
  await core.connect(seller).acceptDeal(1);
  console.log("✅ Seller accepted deal");
  
  // Seller submits work
  const deliveryHash = ethers.keccak256(ethers.toUtf8Bytes("https://website.com"));
  await core.connect(seller).submitWork(1, deliveryHash);
  console.log("✅ Work submitted");
  
  // Buyer approves
  await core.connect(buyer).approveDeal(1);
  console.log("✅ Payment released!");
  
  // Check deal status
  const deal = await core.getDeal(1);
  console.log("Deal status:", deal.status); // Should be 6 (Closed)
}

main();
```

Run it:
```bash
npx hardhat run test-deal.js --network localhost
```

---

## 📊 Check Status

### Get Deal Info

```javascript
const deal = await core.getDeal(1);
console.log({
  buyer: deal.buyer,
  seller: deal.seller,
  amount: ethers.formatEther(deal.amount),
  status: deal.status,
  termsHash: deal.termsHash
});
```

### Check Total Deals

```javascript
const count = await core.dealCount();
console.log("Total deals:", count);
```

---

## 🧪 Next Steps

### 1. Explore More Features

```bash
# Run with gas reporting
npm run test:gas

# Check code coverage
npm run coverage
```

### 2. Read Documentation

- **User Guide**: `README.md`
- **Technical Spec**: `TECHNICAL_SPEC.md`
- **Deployment**: `DEPLOYMENT_GUIDE.md`
- **Full Summary**: `PROJECT_SUMMARY.md`

### 3. Try Different Scenarios

**Timeout Test**:
```javascript
// Create deal and fast-forward time
await core.createDealETH(...);
await ethers.provider.send("evm_increaseTime", [86401]); // Skip 1 day
await core.cancelDeal(1); // Will refund buyer
```

**Dispute Test**:
```javascript
await core.createDealETH(...);
await core.connect(seller).acceptDeal(1);
await core.connect(seller).submitWork(1, hash);
await core.connect(buyer).raiseDispute(1, evidenceHash);
// Arbiter resolves
await core.connect(arbiter).resolveDispute(1, 60, 40, resolutionHash);
```

### 4. Deploy to Testnet

```bash
# Get test ETH from faucet
# Configure .env
cp .env.example .env
nano .env

# Deploy
npm run deploy:testnet
```

---

## 🆘 Troubleshooting

### "Cannot find module"
```bash
npm install
```

### "Compilation failed"
```bash
npm run clean
npm run compile
```

### "Network connection error"
```bash
# Check if local node is running
npx hardhat node
```

### "Transaction reverted"
- Check if you're using correct addresses
- Ensure sufficient ETH balance
- Verify deal status before operation

---

## 📚 Key Concepts

### Deal States
- **Created**: Waiting for seller
- **Accepted**: Work in progress
- **Submitted**: Awaiting buyer review
- **Approved**: Payment released
- **Disputed**: Under arbitration
- **Cancelled**: Refunded
- **Closed**: Complete

### Time Windows
- **Accept Window**: How long seller has to accept
- **Submit Window**: How long to complete work
- **Confirm Window**: How long buyer has to review

### Fees
- **Platform Fee**: 2% (goes to treasury)
- **Arbiter Fee**: 1% (only if disputed)

---

## 🎯 Common Tasks

### Create ETH Deal
```javascript
await core.createDealETH(seller, termsHash, 86400, 604800, 259200, { value: amount });
```

### Create ERC20 Deal
```javascript
await token.approve(core.address, amount);
await core.createDealERC20(seller, token.address, amount, termsHash, 86400, 604800, 259200);
```

### Check if Deal Timed Out
```javascript
const deal = await core.getDeal(dealId);
if (block.timestamp > deal.acceptDeadline && deal.status === 0) {
  await core.cancelDeal(dealId); // Can cancel
}
```

---

## ✅ Quick Reference

| Command | Purpose |
|---------|---------|
| `npm install` | Install dependencies |
| `npm run compile` | Compile contracts |
| `npm test` | Run tests |
| `npm run test:gas` | Gas analysis |
| `npm run coverage` | Test coverage |
| `npx hardhat node` | Local blockchain |
| `npm run deploy:local` | Deploy locally |
| `npm run deploy:testnet` | Deploy to testnet |

---

## 🔗 Resources

- **Main Docs**: [`README.md`](./README.md)
- **Technical Details**: [`TECHNICAL_SPEC.md`](./TECHNICAL_SPEC.md)
- **Deployment Guide**: [`DEPLOYMENT_GUIDE.md`](./DEPLOYMENT_GUIDE.md)
- **Hardhat Docs**: https://hardhat.org/docs
- **Ethers.js Docs**: https://docs.ethers.org/v6/

---

<p align="center">
  <strong>Ready to build? Let's go! 🚀</strong>
</p>

<p align="center">
  Questions? Join our <a href="https://discord.gg/ybz">Discord</a> or email <a href="mailto:hello@ybz.io">hello@ybz.io</a>
</p>

