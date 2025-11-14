const { ethers } = require("hardhat");

/**
 * Deployment script for YBZ.io Escrow Platform
 * 
 * Note: All contracts are immutable (NOT upgradeable) by design
 * 
 * Deployment steps:
 * 1. Deploy YBZFeeManager
 * 2. Deploy YBZTreasury
 * 3. Deploy YBZArbitration
 * 4. Deploy YBZPriceOracle
 * 5. Deploy YBZCore (main contract)
 * 6. Configure initial settings
 */
async function main() {
  console.log("\n🚀 Starting YBZ.io Platform Deployment...\n");
  console.log("⚠️  Note: Contracts are IMMUTABLE (not upgradeable)\n");

  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with account:", deployer.address);
  console.log("Account balance:", ethers.formatEther(await ethers.provider.getBalance(deployer.address)), "ETH\n");

  // ============ Configuration ============
  const config = {
    // Fee configuration
    defaultPlatformFeeBps: 200,  // 2%
    defaultArbiterFeeBps: 100,   // 1%
    
    // Treasury withdrawal address
    withdrawalAddress: "0x31BC0E77a629bE095B58Fc428c84541Aee811111",  // Platform fee collection address
    
    // Initial arbiters (use deployer for testnet)
    initialArbiters: [
      deployer.address,
      // Add real arbiter addresses for mainnet
    ],
  };

  console.log("📋 Configuration:");
  console.log("  Platform Fee:", config.defaultPlatformFeeBps / 100, "%");
  console.log("  Arbiter Fee:", config.defaultArbiterFeeBps / 100, "%");
  console.log("  Withdrawal Address:", config.withdrawalAddress);
  console.log("  Initial Arbiters:", config.initialArbiters.length);
  console.log("");

  // ============ Deploy FeeManager ============
  console.log("📦 Deploying YBZFeeManager...");
  const YBZFeeManager = await ethers.getContractFactory("YBZFeeManager");
  const feeManager = await YBZFeeManager.deploy(
    deployer.address,
    config.defaultPlatformFeeBps,
    config.defaultArbiterFeeBps
  );
  await feeManager.waitForDeployment();
  const feeManagerAddress = await feeManager.getAddress();
  console.log("✅ YBZFeeManager deployed to:", feeManagerAddress);
  console.log("");

  // ============ Deploy Treasury ============
  console.log("📦 Deploying YBZTreasury...");
  const YBZTreasury = await ethers.getContractFactory("YBZTreasury");
  const treasury = await YBZTreasury.deploy(
    deployer.address,
    config.withdrawalAddress
  );
  await treasury.waitForDeployment();
  const treasuryAddress = await treasury.getAddress();
  console.log("✅ YBZTreasury deployed to:", treasuryAddress);
  console.log("   Withdrawal Address:", config.withdrawalAddress);
  console.log("   Withdrawal Delay: 24 hours");
  console.log("");

  // ============ Deploy Arbitration ============
  console.log("📦 Deploying YBZArbitration...");
  const YBZArbitration = await ethers.getContractFactory("YBZArbitration");
  const arbitration = await YBZArbitration.deploy(
    deployer.address,
    config.initialArbiters
  );
  await arbitration.waitForDeployment();
  const arbitrationAddress = await arbitration.getAddress();
  console.log("✅ YBZArbitration deployed to:", arbitrationAddress);
  console.log("");

  // ============ Deploy PriceOracle ============
  console.log("📦 Deploying YBZPriceOracle...");
  const YBZPriceOracle = await ethers.getContractFactory("YBZPriceOracle");
  const priceOracle = await YBZPriceOracle.deploy(deployer.address);
  await priceOracle.waitForDeployment();
  const priceOracleAddress = await priceOracle.getAddress();
  console.log("✅ YBZPriceOracle deployed to:", priceOracleAddress);
  console.log("");

  // ============ Deploy Core ============
  console.log("📦 Deploying YBZCore...");
  const YBZCore = await ethers.getContractFactory("YBZCore");
  const core = await YBZCore.deploy(
    deployer.address,
    feeManagerAddress,
    treasuryAddress,
    arbitrationAddress,
    priceOracleAddress
  );
  await core.waitForDeployment();
  const coreAddress = await core.getAddress();
  console.log("✅ YBZCore deployed to:", coreAddress);
  console.log("");

  // ============ Configure Permissions ============
  console.log("⚙️  Configuring permissions...");

  // Grant TREASURY_ROLE to Core contract so it can deposit fees
  const TREASURY_ROLE = ethers.keccak256(ethers.toUtf8Bytes("TREASURY_ROLE"));
  console.log("  Granting TREASURY_ROLE to Core contract...");
  await treasury.grantRole(TREASURY_ROLE, coreAddress);
  console.log("  ✅ TREASURY_ROLE granted");

  // Allow Core contract to register disputes
  console.log("  Configuring arbitration permissions...");
  // (Arbitration registerDispute can be called by any address in this design)
  console.log("  ✅ Arbitration configured");

  console.log("");

  // ============ Configure Price Oracle ============
  console.log("⚙️  Configuring price oracle...");
  
  // Set manual ETH price (for testnet/localhost)
  // For mainnet, you should use Chainlink price feeds instead
  // ETH/USD price with 8 decimals (e.g., 250000000000 = $2500.00)
  const ethPriceUSD = ethers.parseUnits("2500", 8); // $2500/ETH
  console.log("  Setting manual ETH price: $2500.00 (18 decimals)");
  await priceOracle.setManualPrice(ethers.ZeroAddress, ethPriceUSD, 18); // ETH has 18 decimals
  console.log("  ✅ ETH price set");
  
  console.log("");

  // ============ Add Common Tokens to Whitelist ============
  console.log("⚙️  Whitelisting common tokens...");
  
  // ETH is already whitelisted by default
  console.log("  ✅ ETH (native) whitelisted by default");

  // Add USDT, USDC as stablecoins (unified management in YBZCore)
  // For mainnet, use actual USDT/USDC addresses
  if (network.name === "hardhat" || network.name === "localhost") {
    console.log("  (Localhost: USDT/USDC config available but not deployed)");
    // Example for when you deploy mock USDT/USDC:
    // await core.addStablecoin(USDT_ADDRESS, 6); // USDT is 6 decimals
    // await core.addStablecoin(USDC_ADDRESS, 6); // USDC is 6 decimals
  } else if (network.name === "sepolia") {
    // Sepolia testnet (replace with actual testnet stablecoin addresses)
    // const USDT_ADDRESS = "0x...";
    // const USDC_ADDRESS = "0x...";
    // await core.addStablecoin(USDT_ADDRESS, 6);
    // await core.addStablecoin(USDC_ADDRESS, 6);
    // console.log("  ✅ Testnet stablecoins configured");
  } else if (network.name === "mainnet") {
    // Mainnet USDT/USDC
    const USDT_MAINNET = "0xdAC17F958D2ee523a2206206994597C13D831ec7";
    const USDC_MAINNET = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48";
    
    console.log("  Configuring USDT (6 decimals)...");
    await core.addStablecoin(USDT_MAINNET, 6);
    
    console.log("  Configuring USDC (6 decimals)...");
    await core.addStablecoin(USDC_MAINNET, 6);
    
    console.log("  ✅ Mainnet stablecoins configured");
  }

  console.log("");

  // ============ Deployment Summary ============
  console.log("═══════════════════════════════════════════════");
  console.log("🎉 Deployment Complete!");
  console.log("═══════════════════════════════════════════════");
  console.log("");
  console.log("📝 Contract Addresses:");
  console.log("  YBZCore:        ", coreAddress);
  console.log("  YBZFeeManager:  ", feeManagerAddress);
  console.log("  YBZTreasury:    ", treasuryAddress);
  console.log("  YBZArbitration: ", arbitrationAddress);
  console.log("  YBZPriceOracle: ", priceOracleAddress);
  console.log("");
  console.log("📋 Configuration:");
  console.log("  Network:        ", network.name);
  console.log("  Deployer:       ", deployer.address);
  console.log("  Platform Fee:   ", config.defaultPlatformFeeBps / 100, "%");
  console.log("  Arbiter Fee:    ", config.defaultArbiterFeeBps / 100, "%");
  console.log("");
  console.log("🔐 Security:");
  console.log("  Admin:          ", deployer.address);
  console.log("  Multi-sig:      ", config.treasuryApprovers.length, "approvers,", config.treasuryThreshold, "threshold");
  console.log("  Immutable:      ", "✅ NOT upgradeable");
  console.log("");
  console.log("⚠️  IMPORTANT NEXT STEPS:");
  console.log("  1. Verify contracts on block explorer");
  console.log("  2. Test all core functionality thoroughly");
  console.log("  3. Transfer admin role to multi-sig (mainnet)");
  console.log("  4. Get security audit before mainnet launch");
  console.log("  5. ⚠️  Contracts are NOT upgradeable - deploy carefully!");
  console.log("");
  console.log("═══════════════════════════════════════════════");

  // Save deployment addresses
  const deploymentInfo = {
    network: network.name,
    timestamp: new Date().toISOString(),
    deployer: deployer.address,
    contracts: {
      YBZCore: coreAddress,
      YBZFeeManager: feeManagerAddress,
      YBZTreasury: treasuryAddress,
      YBZArbitration: arbitrationAddress,
      YBZPriceOracle: priceOracleAddress,
    },
    config: config,
  };

  const fs = require("fs");
  const path = require("path");
  const deploymentsDir = path.join(__dirname, "..", "deployments");
  
  if (!fs.existsSync(deploymentsDir)) {
    fs.mkdirSync(deploymentsDir, { recursive: true });
  }

  const deploymentFile = path.join(
    deploymentsDir,
    `${network.name}-${Date.now()}.json`
  );
  
  fs.writeFileSync(deploymentFile, JSON.stringify(deploymentInfo, null, 2));
  console.log("💾 Deployment info saved to:", deploymentFile);
  console.log("");

  return {
    core,
    feeManager,
    treasury,
    arbitration,
    priceOracle,
  };
}

// Execute deployment
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

module.exports = { main };

