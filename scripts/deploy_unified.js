const { ethers, network } = require("hardhat");

async function main() {
  console.log("═══════════════════════════════════════════════");
  console.log("🚀 YBZ Unified Escrow Deployment");
  console.log("═══════════════════════════════════════════════");
  console.log("");
  
  const [deployer] = await ethers.getSigners();
  console.log("Deployer address:", deployer.address);
  console.log("Network:", network.name);
  console.log("");
  
  // ============ Configuration ============
  
  const config = {
    admin: deployer.address,
    withdrawalAddress: "0x31BC0E77a629bE095B58Fc428c84541Aee811111"
    // Arbiters are hardcoded in contract:
    // - 0xB1BB66C47DEE78b91E8AEEb6E74e66e02CA34567
    // - 0xBf3a2c7c9bC27e3143dF965fFa80E421f5445678
  };
  
  // ============ Deploy YBZCore (Unified Contract) ============
  
  console.log("📦 Deploying YBZCore (All-in-One)...");
  console.log("  Network Chain ID:", await ethers.provider.getNetwork().then(n => n.chainId));
  console.log("");
  
  const YBZCore = await ethers.getContractFactory("YBZCore");
  const core = await YBZCore.deploy(
    config.admin,
    config.withdrawalAddress
  );
  
  await core.waitForDeployment();
  const coreAddress = await core.getAddress();
  
  console.log("✅ YBZCore deployed to:", coreAddress);
  console.log("");
  
  // ============ Post-Deployment Configuration ============
  
  const chainId = await ethers.provider.getNetwork().then(n => n.chainId);
  
  if (chainId === 1n) {
    // Mainnet - Everything auto-configured
    console.log("⚙️  Mainnet configuration...");
    console.log("  ✅ Chainlink ETH/USD: Auto-configured");
    console.log("  ✅ USDT & USDC: Auto-configured");
    
    const stablecoins = await core.getSupportedStablecoins();
    console.log("  Registered stablecoins:", stablecoins.length);
    console.log("");
  } else {
    // Local/Testnet - Manual setup required
    console.log("⚙️  Local/Testnet configuration...");
    console.log("  Setting manual ETH price: $2500.00");
    await core.setManualPrice(ethers.parseUnits("2500", 8));
    console.log("  ✅ Price set");
    console.log("");
    console.log("  ℹ️  Note: Deploy mock stablecoins, then:");
    console.log("     await core.addStablecoin(USDT_ADDRESS, 6)");
    console.log("");
  }
  
  // ============ Deployment Summary ============
  
  console.log("═══════════════════════════════════════════════");
  console.log("🎉 Deployment Complete!");
  console.log("═══════════════════════════════════════════════");
  console.log("");
  console.log("📝 Contract Address:");
  console.log("  YBZCore (Unified): ", coreAddress);
  console.log("");
  console.log("📋 Configuration:");
  console.log("  Network:           ", network.name);
  console.log("  Chain ID:          ", await ethers.provider.getNetwork().then(n => n.chainId));
  console.log("  Admin:             ", config.admin);
  console.log("  Withdrawal Address:", config.withdrawalAddress);
  
  // Show arbiters
  const arbiters = await core.getAllArbiters();
  console.log("  Initial Arbiters:  ", arbiters.length);
  if (arbiters.length > 0) {
    for (let i = 0; i < arbiters.length; i++) {
      console.log("    -", arbiters[i]);
    }
  } else {
    console.log("    (Use registerArbiter() to add arbiters for testing)");
  }
  
  // Show configuration status
  if (chainId === 1n) {
    console.log("  ETH Price Feed:     Chainlink Mainnet ✅");
    console.log("  Stablecoins:        USDT & USDC (auto) ✅");
  } else {
    console.log("  ETH Price Feed:     Manual ($2500 set)");
    console.log("  Stablecoins:        None (test only)");
  }
  console.log("");
  console.log("💰 Fee Structure:");
  console.log("  Platform Fee:       2% (200 bps)");
  console.log("  Arbiter Fee:        1% (100 bps)");
  console.log("  Min Deal Amount:    $20 USD");
  console.log("  Min Platform Fee:   $10 USD");
  console.log("");
  console.log("🔒 Security Features:");
  console.log("  ✅ 24h Withdrawal Time Lock");
  console.log("  ✅ Role-Based Access Control");
  console.log("  ✅ ReentrancyGuard");
  console.log("  ✅ Pausable (Emergency)");
  console.log("  ✅ Immutable Design (No Upgrades)");
  console.log("");
  console.log("📊 Integrated Modules:");
  console.log("  ✅ Fee Management");
  console.log("  ✅ Treasury (Withdrawal)");
  console.log("  ✅ Arbitration System");
  console.log("  ✅ Price Oracle (Chainlink)");
  console.log("  ✅ Stablecoin Registry");
  console.log("");
  console.log("🔗 Next Steps:");
  console.log("  1. Verify contract on Etherscan");
  console.log("  2. Transfer admin role if needed");
  console.log("  3. Register additional arbiters");
  console.log("  4. Configure mainnet stablecoins");
  console.log("  5. Test with small amounts first");
  console.log("");
  console.log("═══════════════════════════════════════════════");
  
  // Save deployment info
  const deployment = {
    network: network.name,
    timestamp: new Date().toISOString(),
    deployer: deployer.address,
    contracts: {
      YBZCore: coreAddress
    },
    config: config
  };
  
  console.log("");
  console.log("Deployment info:", JSON.stringify(deployment, null, 2));
  console.log("");
  
  return deployment;
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

