// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title YBZ.io - Decentralized Escrow Platform
 * @notice "Trustless. Transparent. Guaranteed."
 * @dev Main entry point for YBZ.io escrow system.
 *      Code is Law. Immutable Code is Reliable Law.
 * 
 * @author YBZ.io Team
 * @custom:website https://ybz.io
 * @custom:security-contact security@ybz.io
 * @custom:version 1.0.3
 * @custom:date 2025-10-18
 */

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import "./interfaces/IYBZCore.sol";
import "./libraries/DealValidation.sol";

contract YBZCore is 
    AccessControl,
    ReentrancyGuard,
    Pausable,
    IYBZCore
{
    using SafeERC20 for IERC20;
    using DealValidation for *;
    
    // ============ Roles ============
    
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    bytes32 public constant ARBITER_ROLE = keccak256("ARBITER_ROLE");
    
    // ============ Hardcoded Addresses (Ethereum Mainnet Only) ============
    
    /// @notice Chainlink ETH/USD price feed (Mainnet)
    address public constant CHAINLINK_ETH_USD = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;
    
    /// @notice USDT address (Mainnet)
    address public constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    
    /// @notice USDC address (Mainnet)
    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    
    /// @notice Initial arbiters (hardcoded)
    address public constant ARBITER_1 = 0xB1BB66C47DEE78b91E8AEEb6E74e66e02CA34567;
    address public constant ARBITER_2 = 0xBf3a2c7c9bC27e3143dF965fFa80E421f5445678;

    // ============ State Variables ============
    
    /// @notice Deal counter
    uint256 private _dealIdCounter;
    
    /// @notice Stablecoin configuration
    struct StablecoinInfo {
        bool isActive;      // Whether this stablecoin is supported
        uint8 decimals;     // Token decimals (6 for USDT/USDC, 18 for DAI)
    }
    
    /// @notice All deals
    mapping(uint256 => Deal) private _deals;
    
    /// @notice Dispute resolutions
    mapping(uint256 => DisputeResolution) private _resolutions;
    
    /// @notice Supported stablecoins registry (replaces tokenWhitelist for ERC20)
    /// @dev address(0) is reserved for ETH (not a stablecoin)
    mapping(address => StablecoinInfo) public stablecoins;
    
    /// @notice List of all registered stablecoin addresses
    address[] public stablecoinList;
    
    /// @notice Accumulated platform fees by token (treasury balance)
    /// @dev token => accumulated fee amount
    mapping(address => uint256) public accumulatedFees;
    
    // ============ Fee Management (Integrated) ============
    
    /// @notice Default platform fee in basis points (100 = 1%)
    uint16 public defaultPlatformFeeBps;
    
    /// @notice Default arbiter fee in basis points (100 = 1%)
    uint16 public defaultArbiterFeeBps;
    
    /// @notice Maximum fee in basis points (1000 = 10%)
    uint16 public constant MAX_FEE_BPS = 1000;
    
    /// @notice Tiered fee structure: amount threshold => fee in bps
    mapping(uint256 => uint16) public tieredPlatformFees;
    
    /// @notice Array of tier thresholds for iteration
    uint256[] public tierThresholds;
    
    // ============ Treasury (Integrated) ============
    
    /// @notice Withdrawal destination address
    address public withdrawalAddress;
    
    
    // ============ Arbitration (Integrated) ============
    
    /// @notice Arbiter information
    struct ArbiterInfo {
        bool isActive;
        uint256 totalCases;
        uint256 resolvedCases;
        uint256 reputation; // 0-100 score (not used currently)
        uint16 arbiterFeeBps; // Individual arbiter fee in basis points (can be adjusted by admin)
        uint64 registeredAt;
    }
    
    /// @notice Registered arbiters
    mapping(address => ArbiterInfo) public arbiters;
    
    /// @notice List of all arbiter addresses
    address[] public arbiterList;
    
    // ============ Price Oracle (Integrated - Chainlink) ============
    
    /// @notice Chainlink ETH/USD price feed interface
    AggregatorV3Interface public ethUsdPriceFeed;
    
    /// @notice Cached ETH price (8 decimals)
    uint256 public cachedEthPrice;
    
    /// @notice Price cache timestamp
    uint256 public priceCacheTime;
    
    /// @notice Price cache duration (10 minutes)
    uint256 public constant PRICE_CACHE_DURATION = 10 minutes;
    
    /// @notice Minimum deal amount in USD (8 decimals: 2000_0000_0000 = $20.00)
    uint256 public constant MIN_DEAL_AMOUNT_USD = 20_0000_0000; // $20.00
    
    /// @notice Minimum platform fee in USD (8 decimals: 1000_0000_0000 = $10.00)
    uint256 public constant MIN_FEE_USD = 10_0000_0000; // $10.00
    
    /// @notice Minimum arbiter fee in USD (8 decimals: 5_0000_0000 = $5.00)
    uint256 public constant MIN_ARBITER_FEE_USD = 5_0000_0000; // $5.00
    
    /// @notice Maximum dispute cooldown period (24 hours)
    /// @dev Actual cooldown is dynamic: min(24 hours, confirmWindow / 2)
    /// @dev This prevents buyers from being locked out of disputes in short-term deals
    uint64 public constant MAX_DISPUTE_COOLDOWN = 24 hours;
    
    /// @notice Platform brand message for event marketing
    /// @dev Displayed in blockchain explorers for brand exposure
    string public constant PLATFORM_MESSAGE = "ybz.io - Escrow Layer";
    
    // ============ Events ============
    
    // Core Events (from IYBZCore interface)
    
    // Fee Management Events
    event FeeWithdrawn(address indexed token, address indexed recipient, uint256 amount);
    
    // Arbitration Events (important business operations)
    event ArbiterRegistered(address indexed arbiter, uint64 timestamp);
    event ArbiterRemoved(address indexed arbiter);
    
    // ============ Errors ============
    
    error DisputeCooldownActive(uint64 remainingTime);
    error InvalidFee();
    error InvalidThreshold();
    error TierAlreadyExists();
    error TierNotFound();
    error ArbiterNotFound();
    error ArbiterAlreadyExists();
    error ArbiterInactive();
    error InsufficientBalance();
    error InvalidPrice();
    
    // ============ Constructor ============
    
    /**
     * @notice Constructs the unified escrow contract
     * @param admin Admin address
     * @param withdrawalAddr Initial withdrawal address for fees
     * @dev Everything else is auto-configured (Chainlink, stablecoins, arbiters)
     */
    constructor(
        address admin,
        address withdrawalAddr
    ) {
        require(admin != address(0), "Invalid admin");
        require(withdrawalAddr != address(0), "Invalid withdrawal address");
        
        // Grant roles
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(OPERATOR_ROLE, admin);
        
        // Initialize fee structure
        defaultPlatformFeeBps = 100;  // 1%
        defaultArbiterFeeBps = 100;   // 1%
        
        // Initialize treasury
        withdrawalAddress = withdrawalAddr;
        
        // Auto-configure Chainlink price feed and stablecoins for mainnet
        if (block.chainid == 1) {
            // Ethereum Mainnet - Auto-configure everything
            ethUsdPriceFeed = AggregatorV3Interface(CHAINLINK_ETH_USD);
            
            // Register hardcoded arbiters (mainnet only)
            _registerArbiterInternal(ARBITER_1);
            _registerArbiterInternal(ARBITER_2);
            
            // Auto-register USDT
            stablecoins[USDT] = StablecoinInfo({
                isActive: true,
                decimals: 6
            });
            stablecoinList.push(USDT);
            
            // Auto-register USDC
            stablecoins[USDC] = StablecoinInfo({
                isActive: true,
                decimals: 6
            });
            stablecoinList.push(USDC);
        }
        // For other networks (testnet/localhost), use setManualPrice() for testing
        
        _dealIdCounter = 1; // Start from 1
    }
    
    // ============ Deal Creation ============
    
    /**
     * @notice Creates a new ETH escrow deal
     * @param seller Seller address
     * @param termsHash IPFS hash of deal terms
     * @param acceptWindow Time window for seller to accept (seconds)
     * @param submitWindow Time window for seller to submit work (seconds)
     * @param confirmWindow Time window for buyer to confirm (seconds)
     * @param preferredArbiter Optional: pre-select arbiter (must be active, or address(0) for random)
     * @return dealId New deal identifier
     */
    function createDealETH(
        address seller,
        bytes32 termsHash,
        uint64 acceptWindow,
        uint64 submitWindow,
        uint64 confirmWindow,
        address preferredArbiter
    ) external payable override nonReentrant whenNotPaused returns (uint256 dealId) {
        // Validate inputs
        DealValidation.validateCreateDeal(
            seller,
            msg.value,
            termsHash,
            acceptWindow,
            submitWindow,
            confirmWindow
        );
        
        if (msg.sender == seller) revert DealValidation.InvalidAddress();
        
        // Create deal
        dealId = _createDeal(
            msg.sender,
            seller,
            address(0), // ETH
            msg.value,
            termsHash,
            acceptWindow,
            submitWindow,
            confirmWindow,
            preferredArbiter
        );
        
        // Get created deal data for event
        Deal storage newDeal = _deals[dealId];
        
        emit DealCreated(
            dealId, 
            msg.sender, 
            seller, 
            address(0), 
            msg.value,
            newDeal.creationPriceUSD,
            newDeal.platformFeeBps,
            newDeal.arbiterFeeBps,
            termsHash, 
            acceptWindow, 
            submitWindow, 
            confirmWindow, 
            preferredArbiter, 
            PLATFORM_MESSAGE
        );
    }
    
    /**
     * @notice Creates a new ERC20 escrow deal (USDT/USDC only)
     * @param seller Seller address
     * @param token Token address (must be USDT or USDC)
     * @param amount Token amount
     * @param termsHash IPFS hash of deal terms
     * @param acceptWindow Time window for seller to accept (seconds)
     * @param submitWindow Time window for seller to submit work (seconds)
     * @param confirmWindow Time window for buyer to confirm (seconds)
     * @param preferredArbiter Optional: pre-select arbiter (must be active, or address(0) for random)
     * @return dealId New deal identifier
     * @dev Only stablecoins (USDT/USDC) are supported for ERC20 deals
     */
    function createDealERC20(
        address seller,
        address token,
        uint256 amount,
        bytes32 termsHash,
        uint64 acceptWindow,
        uint64 submitWindow,
        uint64 confirmWindow,
        address preferredArbiter
    ) external override nonReentrant whenNotPaused returns (uint256 dealId) {
        // Validate token is a supported stablecoin
        if (token == address(0)) revert DealValidation.InvalidAddress();
        
        StablecoinInfo memory stablecoin = stablecoins[token];
        require(stablecoin.isActive, "Token is not a supported stablecoin");
        
        // ===== Early USD Amount Check for Stablecoins (Gas Optimization) =====
        // Stablecoins are 1:1 USD, convert to 8 decimals for comparison
        // Formula: amount * 10^(8 - tokenDecimals)
        // Example: 100 USDT (6 decimals) = 100000000 → 10000000000 (8 decimals) = $100
        
        uint256 dealAmountUSD;
        if (stablecoin.decimals <= 8) {
            dealAmountUSD = amount * (10 ** (8 - stablecoin.decimals));
        } else {
            dealAmountUSD = amount / (10 ** (stablecoin.decimals - 8));
        }
        
        // Check minimum deal amount ($20 USD)
        require(dealAmountUSD >= MIN_DEAL_AMOUNT_USD, "Deal amount below $20 minimum");
        
        // Minimum fee ($10) will be enforced in _releaseFunds:
        // - If amount * 2% < $10 → charge $10
        // - If amount * 2% >= $10 → charge 2%
        // This way $20-$500 orders are accepted but pay $10 minimum
        
        // ===== End Early Check =====
        if (seller == address(0)) revert DealValidation.InvalidAddress();
        if (termsHash == bytes32(0)) revert DealValidation.InvalidTermsHash();
        if (acceptWindow < DealValidation.MIN_ACCEPT_WINDOW || acceptWindow > DealValidation.MAX_ACCEPT_WINDOW) {
            revert DealValidation.InvalidTimeWindow();
        }
        if (submitWindow < DealValidation.MIN_SUBMIT_WINDOW || submitWindow > DealValidation.MAX_SUBMIT_WINDOW) {
            revert DealValidation.InvalidTimeWindow();
        }
        if (confirmWindow < DealValidation.MIN_CONFIRM_WINDOW || confirmWindow > DealValidation.MAX_CONFIRM_WINDOW) {
            revert DealValidation.InvalidTimeWindow();
        }
        
        if (msg.sender == seller) revert DealValidation.InvalidAddress();
        
        // Transfer tokens to contract
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        
        // Create deal
        dealId = _createDeal(
            msg.sender,
            seller,
            token,
            amount,
            termsHash,
            acceptWindow,
            submitWindow,
            confirmWindow,
            preferredArbiter
        );
        
        // Get created deal data for event
        Deal storage newDeal = _deals[dealId];
        
        emit DealCreated(
            dealId, 
            msg.sender, 
            seller, 
            token, 
            amount,
            newDeal.creationPriceUSD,
            newDeal.platformFeeBps,
            newDeal.arbiterFeeBps,
            termsHash, 
            acceptWindow, 
            submitWindow, 
            confirmWindow, 
            preferredArbiter, 
            PLATFORM_MESSAGE
        );
    }
    
    /**
     * @notice Internal deal creation logic
     */
    function _createDeal(
        address buyer,
        address seller,
        address token,
        uint256 amount,
        bytes32 termsHash,
        uint64 acceptWindow,
        uint64 submitWindow,
        uint64 confirmWindow,
        address preferredArbiter
    ) internal returns (uint256 dealId) {
        dealId = _dealIdCounter++;
        
        // ============ Arbiter Validation ============
        
        address assignedArbiter = address(0);
        
        // If user pre-selects an arbiter, validate it
        if (preferredArbiter != address(0)) {
            require(
                _isActiveArbiter(preferredArbiter),
                "Preferred arbiter is not active"
            );
            assignedArbiter = preferredArbiter;
        }
        // If address(0), arbiter will be randomly assigned during dispute
        
        // ============ USD Amount Validation ============
        
        uint256 creationPriceUSD = 0;
        
        // Check if token is a stablecoin (registered in our system)
        StablecoinInfo memory stablecoin = stablecoins[token];
        
        if (stablecoin.isActive) {
            // ===== Stablecoin (USDT/USDC/DAI): Simple validation =====
            // Already validated in createDealERC20 (early check)
            // Just confirm minimum deal amount using dynamic decimals
            
            uint256 dealAmountUSD;
            if (stablecoin.decimals <= 8) {
                dealAmountUSD = amount * (10 ** (8 - stablecoin.decimals));
            } else {
                dealAmountUSD = amount / (10 ** (stablecoin.decimals - 8));
            }
            require(dealAmountUSD >= MIN_DEAL_AMOUNT_USD, "Deal amount below $20 minimum");
            
            // Fee will be enforced in _releaseFunds: max(amount * 2%, $10)
            // No rejection here - always accept if >= $20
            
            // creationPriceUSD = 0 for stablecoins
            
        } else {
            // ===== ETH: Query price ONCE and save (with 10-min cache) =====
            // Get ETH price and update cache if needed
            // If cache valid (<10 min): returns cached price (cheap)
            // If cache expired: queries Chainlink and updates cache (expensive, but helps next user)
            creationPriceUSD = _getEthPriceUSD();
            require(creationPriceUSD > 0, "Invalid price");
            
            // Calculate USD values using this single price query
            uint256 dealAmountUSD = (amount * creationPriceUSD) / 1e18;
            
            // Check minimum deal amount ($20 USD)
            require(dealAmountUSD >= MIN_DEAL_AMOUNT_USD, "Deal amount below $20 minimum");
            
        }
        
        // ============ End USD Validation ============
        
        // Get fee rates
        uint16 platformFeeBps = _getPlatformFeeBps(amount);
        
        // Get arbiter fee rate: use assigned arbiter's rate if pre-selected, otherwise default
        uint16 arbiterFeeBps;
        if (assignedArbiter != address(0)) {
            arbiterFeeBps = arbiters[assignedArbiter].arbiterFeeBps;
        } else {
            arbiterFeeBps = defaultArbiterFeeBps;
        }
        
        // Calculate deadlines
        uint64 now64 = uint64(block.timestamp);
        uint64 acceptDeadline = now64 + acceptWindow;
        uint64 submitDeadline = acceptDeadline + submitWindow;
        uint64 confirmDeadline = submitDeadline + confirmWindow;
        
        _deals[dealId] = Deal({
            buyer: buyer,
            seller: seller,
            token: token,
            amount: amount,
            creationPriceUSD: creationPriceUSD,
            platformFeeBps: platformFeeBps,
            arbiterFeeBps: arbiterFeeBps,
            termsHash: termsHash,
            deliveryHash: bytes32(0),
            acceptDeadline: acceptDeadline,
            submitDeadline: submitDeadline,
            confirmDeadline: confirmDeadline,
            acceptWindow: acceptWindow,
            submitWindow: submitWindow,
            confirmWindow: confirmWindow,
            createdAt: now64,
            submittedAt: 0,
            arbiter: assignedArbiter,
            status: DealStatus.Created,
            refundRequested: false,
            // Deadline proposal fields
            proposedSubmitWindow: 0,
            proposedConfirmWindow: 0,
            proposedBy: address(0),
            proposalAccepted: false
        });
    }
    
    // ============ Deal Workflow ============
    
    /**
     * @notice Seller accepts the deal
     * @param dealId Deal identifier
     */
    function acceptDeal(uint256 dealId) external override nonReentrant whenNotPaused {
        Deal storage deal = _deals[dealId];
        
        // Validations
        DealValidation.requireStatus(deal.status, DealStatus.Created);
        DealValidation.requireAuthorized(deal, msg.sender, false);
        DealValidation.requireDeadlineNotPassed(deal.acceptDeadline);
        
        // Update status
        deal.status = DealStatus.Accepted;
        
        emit DealAccepted(dealId, msg.sender, deal.submitDeadline);
    }
    
    /**
     * @notice Seller rejects the deal
     * @param dealId Deal identifier
     * @dev Only seller can reject, must be in Created status, refunds buyer
     */
    function rejectDeal(uint256 dealId) external override nonReentrant whenNotPaused {
        Deal storage deal = _deals[dealId];
        
        // Validations
        DealValidation.requireStatus(deal.status, DealStatus.Created);
        DealValidation.requireAuthorized(deal, msg.sender, false);
        
        // Update status
        deal.status = DealStatus.Cancelled;
        
        // Refund buyer (full amount, no fees)
        _transferFunds(deal.token, deal.buyer, deal.amount);
        
        emit DealRejected(dealId, msg.sender);
        
        // Clean up storage
        _closeDeal(dealId);
    }
    
    /**
     * @notice Seller submits work
     * @param dealId Deal identifier
     * @param deliveryHash IPFS hash of delivery proof
     */
    function submitWork(uint256 dealId, bytes32 deliveryHash) 
        external 
        override 
        nonReentrant 
        whenNotPaused 
    {
        Deal storage deal = _deals[dealId];
        
        // Validations
        DealValidation.requireStatus(deal.status, DealStatus.Accepted);
        DealValidation.requireAuthorized(deal, msg.sender, false);
        DealValidation.requireDeadlineNotPassed(deal.submitDeadline);
        
        if (deliveryHash == bytes32(0)) revert DealValidation.InvalidTermsHash();
        
        // Update deal
        deal.deliveryHash = deliveryHash;
        deal.submittedAt = uint64(block.timestamp);
        deal.status = DealStatus.Submitted;
        
        // Recalculate confirmDeadline based on actual submission time
        // This gives buyer full confirmWindow starting from NOW
        deal.confirmDeadline = uint64(block.timestamp) + deal.confirmWindow;
        
        emit WorkSubmitted(dealId, deliveryHash, deal.confirmDeadline);
    }
    
    /**
     * @notice Buyer approves and releases payment
     * @param dealId Deal identifier
     */
    function approveDeal(uint256 dealId) external override nonReentrant whenNotPaused {
        Deal storage deal = _deals[dealId];
        
        // Validations
        DealValidation.requireStatus(deal.status, DealStatus.Submitted);
        DealValidation.requireAuthorized(deal, msg.sender, true);
        DealValidation.requireDeadlineNotPassed(deal.confirmDeadline);
        
        // Mark as approved
        deal.status = DealStatus.Approved;
        
        // Release funds
        _releaseFunds(dealId, deal.seller, 100, 0);
        
        emit DealApproved(dealId, deal.seller, deal.amount);
        
        // Clean up storage
        _closeDeal(dealId);
    }
    
    /**
     * @notice Raises a dispute
     * @param dealId Deal identifier
     * @param evidenceHash IPFS hash of evidence
     * @dev Requires 24-hour cooldown after work submission to prevent malicious disputes
     */
    function raiseDispute(uint256 dealId, bytes32 evidenceHash) 
        external 
        override 
        nonReentrant 
        whenNotPaused 
    {
        Deal storage deal = _deals[dealId];
        
        // Can dispute in Accepted or Submitted states
        if (deal.status != DealStatus.Accepted && deal.status != DealStatus.Submitted) {
            revert DealValidation.InvalidStatus(deal.status, DealStatus.Submitted);
        }
        
        // Only buyer or seller can raise dispute
        if (msg.sender != deal.buyer && msg.sender != deal.seller) {
            revert DealValidation.Unauthorized();
        }
        
        // Enforce dynamic cooldown period after work submission
        if (deal.status == DealStatus.Submitted && deal.submittedAt > 0) {
            // Calculate cooldown based on total confirm time (fixed at submission)
            // cooldown = min(24h, confirmWindow / 2)
            uint64 totalConfirmTime = deal.confirmDeadline - deal.submittedAt;
            uint64 cooldownPeriod = totalConfirmTime < (MAX_DISPUTE_COOLDOWN * 2) 
                ? totalConfirmTime / 2 
                : MAX_DISPUTE_COOLDOWN;
            
            uint64 timeSinceSubmission = uint64(block.timestamp) - deal.submittedAt;
            if (timeSinceSubmission < cooldownPeriod) {
                uint64 remainingTime = cooldownPeriod - timeSinceSubmission;
                revert DisputeCooldownActive(remainingTime);
            }
        }
        
        // Clear any pending deadline proposal when dispute is raised
        if (deal.proposedBy != address(0)) {
            deal.proposedBy = address(0);
            deal.proposedSubmitWindow = 0;
            deal.proposedConfirmWindow = 0;
            deal.proposalAccepted = false;
        }
        
        // Select arbiter: use preferred arbiter if set, otherwise random
        address arbiter;
        if (deal.arbiter != address(0)) {
            // User pre-selected arbiter during deal creation
            arbiter = deal.arbiter;
            // Verify arbiter is still active
            require(_isActiveArbiter(arbiter), "Pre-selected arbiter is no longer active");
        } else {
            // No preferred arbiter, select randomly
            arbiter = _selectRandomArbiter();
            deal.arbiter = arbiter;
            // Update arbiter fee to match selected arbiter's rate
            deal.arbiterFeeBps = arbiters[arbiter].arbiterFeeBps;
        }
        
        deal.status = DealStatus.Disputed;
        
        // Register dispute (update arbiter stats)
        _registerDispute(dealId, msg.sender, arbiter);
        
        emit DisputeRaised(dealId, msg.sender, evidenceHash);
    }
    
    /**
     * @notice Resolves a dispute (arbiter only)
     * @param dealId Deal identifier
     * @param buyerRatio Buyer's share (0-100)
     * @param sellerRatio Seller's share (0-100)
     * @param evidenceHash Resolution evidence hash
     */
    function resolveDispute(
        uint256 dealId,
        uint8 buyerRatio,
        uint8 sellerRatio,
        bytes32 evidenceHash
    ) external override nonReentrant whenNotPaused {
        Deal storage deal = _deals[dealId];
        
        // Validations
        DealValidation.requireStatus(deal.status, DealStatus.Disputed);
        DealValidation.validateResolutionRatio(buyerRatio, sellerRatio);
        
        // Check if sender is authorized to resolve dispute
        bool isAssignedArbiter = (msg.sender == deal.arbiter);
        bool isOperator = hasRole(OPERATOR_ROLE, msg.sender);
        
        if (!isAssignedArbiter && !isOperator) {
            revert DealValidation.Unauthorized();
        }
        
        // If arbiter is resolving, verify they are still active
        // This prevents deactivated arbiters from resolving disputes
        // Operators can always resolve (emergency override)
        if (isAssignedArbiter && !isOperator) {
            require(
                _isActiveArbiter(msg.sender),
                "Arbiter has been deactivated"
            );
        }
        
        // Mark as resolved
        deal.status = DealStatus.Resolved;
        
        // Record resolution
        _resolutions[dealId] = DisputeResolution({
            arbiter: msg.sender,
            buyerRatio: buyerRatio,
            sellerRatio: sellerRatio,
            evidenceHash: evidenceHash,
            resolvedAt: uint64(block.timestamp),
            arbiterFee: (deal.amount * deal.arbiterFeeBps) / 10000
        });
        
        // Release funds according to ratio
        _releaseFunds(dealId, address(0), buyerRatio, sellerRatio);
        
        // Update arbiter statistics
        _resolveDisputeRecord(msg.sender);
        
        emit DisputeResolved(dealId, msg.sender, buyerRatio, sellerRatio, evidenceHash);
        
        // Clean up
        _closeDeal(dealId);
    }
    
    /**
     * @notice Auto-cancel if seller doesn't accept in time
     * @param dealId Deal identifier
     * @dev Anyone can trigger after acceptDeadline
     */
    function autoCancel(uint256 dealId) external override nonReentrant whenNotPaused {
        Deal storage deal = _deals[dealId];
        
        // Must be in Created status
        DealValidation.requireStatus(deal.status, DealStatus.Created);
        
        // Accept deadline must have passed
        DealValidation.requireDeadlinePassed(deal.acceptDeadline);
        
        // Update status
        deal.status = DealStatus.Cancelled;
        
        // Refund buyer (full amount, no fees)
        _transferFunds(deal.token, deal.buyer, deal.amount);
        
        emit DealFinalized(
            dealId, 
            deal.buyer, 
            msg.sender, 
            deal.amount, 
            DealStatus.Cancelled,
            PLATFORM_MESSAGE,
            "Accept timeout - seller did not respond"
        );
        
        // Clean up storage
        _closeDeal(dealId);
    }
    
    /**
     * @notice Cancel deal if seller accepted but didn't submit work
     * @param dealId Deal identifier
     * @dev Only buyer can trigger after submitDeadline
     */
    function cancelDeal(uint256 dealId) external override nonReentrant whenNotPaused {
        Deal storage deal = _deals[dealId];
        
        // Must be in Accepted status
        DealValidation.requireStatus(deal.status, DealStatus.Accepted);
        
        // Only buyer can cancel
        DealValidation.requireAuthorized(deal, msg.sender, true);
        
        // Submit deadline must have passed
        DealValidation.requireDeadlinePassed(deal.submitDeadline);
        
        deal.status = DealStatus.Cancelled;
        
        // Refund buyer
        _transferFunds(deal.token, deal.buyer, deal.amount);
        
        emit DealFinalized(
            dealId, 
            deal.buyer, 
            msg.sender, 
            deal.amount, 
            DealStatus.Cancelled,
            PLATFORM_MESSAGE,
            "Submit timeout - seller did not deliver"
        );
        
        _closeDeal(dealId);
    }
    
    /**
     * @notice Auto-refund (buyer can trigger after submit deadline)
     * @param dealId Deal identifier
     * @dev Removed whenNotPaused to allow fund release during pause
     */
    function autoRefund(uint256 dealId) external override nonReentrant {
        Deal storage deal = _deals[dealId];
        
        DealValidation.requireStatus(deal.status, DealStatus.Accepted);
        DealValidation.requireAuthorized(deal, msg.sender, true);
        DealValidation.requireDeadlinePassed(deal.submitDeadline);
        
        deal.status = DealStatus.Cancelled;
        
        // Refund buyer
        _transferFunds(deal.token, deal.buyer, deal.amount);
        
        emit DealFinalized(
            dealId, 
            deal.buyer, 
            msg.sender, 
            deal.amount, 
            DealStatus.Cancelled,
            PLATFORM_MESSAGE,
            "Auto-refund - submit timeout"
        );
        
        _closeDeal(dealId);
    }
    
    /**
     * @notice Buyer requests mutual refund (e.g., seller can't fulfill)
     * @param dealId Deal identifier
     * @dev Seller can approve with approveRefund()
     */
    function requestRefund(uint256 dealId) external override nonReentrant whenNotPaused {
        Deal storage deal = _deals[dealId];
        
        // Can request refund in Accepted or Submitted states
        if (deal.status != DealStatus.Accepted && deal.status != DealStatus.Submitted) {
            revert DealValidation.InvalidStatus(deal.status, DealStatus.Accepted);
        }
        
        // Only buyer can request refund
        DealValidation.requireAuthorized(deal, msg.sender, true);
        
        // Mark as refund requested
        deal.refundRequested = true;
        
        emit RefundRequested(dealId, msg.sender);
    }
    
    /**
     * @notice Seller approves buyer's refund request
     * @param dealId Deal identifier
     * @dev Triggers full refund to buyer (no fees)
     */
    function approveRefund(uint256 dealId) external override nonReentrant whenNotPaused {
        Deal storage deal = _deals[dealId];
        
        // Must have refund request pending
        require(deal.refundRequested, "No refund request");
        
        // Can approve refund in Accepted or Submitted states
        if (deal.status != DealStatus.Accepted && deal.status != DealStatus.Submitted) {
            revert DealValidation.InvalidStatus(deal.status, DealStatus.Accepted);
        }
        
        // Only seller can approve
        DealValidation.requireAuthorized(deal, msg.sender, false);
        
        // Update status
        deal.status = DealStatus.Cancelled;
        
        // Full refund to buyer (no fees - mutual agreement)
        _transferFunds(deal.token, deal.buyer, deal.amount);
        
        emit DealFinalized(
            dealId, 
            deal.buyer, 
            msg.sender, 
            deal.amount, 
            DealStatus.Cancelled,
            PLATFORM_MESSAGE,
            "Mutual agreement - seller approved refund"
        );
        
        _closeDeal(dealId);
    }
    
    /**
     * @notice Emergency fund release during contract pause
     * @param dealId Deal identifier
     * @dev Only admin can trigger, refunds to buyer as safest option
     */
    function emergencyRelease(uint256 dealId) 
        external 
        override
        nonReentrant 
        whenPaused 
        onlyRole(DEFAULT_ADMIN_ROLE) 
    {
        Deal storage deal = _deals[dealId];
        
        // Can only release if not already finalized
        require(
            deal.status != DealStatus.Closed && 
            deal.status != DealStatus.Approved,
            "Already finalized"
        );
        
        deal.status = DealStatus.Cancelled;
        
        // Emergency refund to buyer (safest option during emergency)
        _transferFunds(deal.token, deal.buyer, deal.amount);
        
        emit DealFinalized(
            dealId, 
            deal.buyer, 
            msg.sender, 
            deal.amount, 
            DealStatus.Cancelled,
            PLATFORM_MESSAGE,
            "Emergency release during pause"
        );
        
        _closeDeal(dealId);
    }
    
    /**
     * @notice Auto-release (anyone can trigger after confirm deadline)
     * @param dealId Deal identifier
     * @dev Removed whenNotPaused to allow fund release during pause
     */
    function autoRelease(uint256 dealId) external override nonReentrant {
        Deal storage deal = _deals[dealId];
        
        if (!DealValidation.canAutoRelease(deal)) {
            revert DealValidation.DeadlineNotReached();
        }
        
        deal.status = DealStatus.Approved;
        
        // Release to seller
        _releaseFunds(dealId, deal.seller, 100, 0);
        
        emit DealFinalized(
            dealId,
            deal.seller,
            msg.sender,
            deal.amount,
            DealStatus.Closed,
            PLATFORM_MESSAGE,
            "Auto-release - buyer did not respond in time"
        );
        
        _closeDeal(dealId);
    }
    
    // ============ Deadline Management ============
    
    /**
     * @notice Propose new deadline windows for a deal
     * @param dealId Deal identifier
     * @param newSubmitWindow New submit window in seconds
     * @param newConfirmWindow New confirm window in seconds
     * @dev Only buyer or seller can propose, must be in valid status
     */
    function proposeNewDeadline(
        uint256 dealId,
        uint64 newSubmitWindow,
        uint64 newConfirmWindow
    ) external override nonReentrant {
        Deal storage deal = _deals[dealId];
        
        // Validate deal exists
        require(deal.buyer != address(0), "Deal does not exist");
        
        // Only buyer or seller can propose
        require(
            msg.sender == deal.buyer || msg.sender == deal.seller,
            "Not authorized"
        );
        
        // Can only propose in active states
        require(
            deal.status == DealStatus.Accepted || 
            deal.status == DealStatus.Submitted,
            "Invalid status for deadline proposal"
        );
        
        // Validate new windows
        require(
            newSubmitWindow >= DealValidation.MIN_SUBMIT_WINDOW && 
            newSubmitWindow <= DealValidation.MAX_SUBMIT_WINDOW,
            "Invalid submit window"
        );
        require(
            newConfirmWindow >= DealValidation.MIN_CONFIRM_WINDOW && 
            newConfirmWindow <= DealValidation.MAX_CONFIRM_WINDOW,
            "Invalid confirm window"
        );
        
        // Cannot propose if already has pending proposal
        require(deal.proposedBy == address(0), "Proposal already pending");
        
        // Store proposal
        deal.proposedSubmitWindow = newSubmitWindow;
        deal.proposedConfirmWindow = newConfirmWindow;
        deal.proposedBy = msg.sender;
        deal.proposalAccepted = false;
        
        emit DeadlineProposed(dealId, msg.sender, newSubmitWindow, newConfirmWindow);
    }
    
    /**
     * @notice Accept deadline proposal from the other party
     * @param dealId Deal identifier
     * @dev Only the non-proposer can accept
     */
    function acceptDeadlineProposal(uint256 dealId) external override nonReentrant {
        Deal storage deal = _deals[dealId];
        
        // Validate deal exists
        require(deal.buyer != address(0), "Deal does not exist");
        
        // Must have pending proposal
        require(deal.proposedBy != address(0), "No proposal pending");
        
        // Cannot self-approve
        require(msg.sender != deal.proposedBy, "Cannot self-approve");
        
        // Must be the other party
        require(
            msg.sender == deal.buyer || msg.sender == deal.seller,
            "Not authorized"
        );
        
        // Update windows
        deal.submitWindow = deal.proposedSubmitWindow;
        deal.confirmWindow = deal.proposedConfirmWindow;
        
        // Recalculate deadlines if deal is in Submitted status
        if (deal.status == DealStatus.Submitted) {
            deal.confirmDeadline = uint64(block.timestamp) + deal.confirmWindow;
        }
        
        // Clear proposal
        deal.proposedBy = address(0);
        deal.proposedSubmitWindow = 0;
        deal.proposedConfirmWindow = 0;
        deal.proposalAccepted = true;
        
        emit DeadlineUpdated(dealId, deal.submitWindow, deal.confirmWindow, msg.sender);
    }
    
    /**
     * @notice Releases funds with fee distribution
     * @param dealId Deal identifier
     * @param primaryRecipient Primary recipient (if ratio is 100/0)
     * @param buyerRatio Buyer's share (0-100)
     * @param sellerRatio Seller's share (0-100)
     */
    function _releaseFunds(
        uint256 dealId,
        address primaryRecipient,
        uint8 buyerRatio,
        uint8 sellerRatio
    ) internal {
        Deal storage deal = _deals[dealId];
        
        // Calculate platform fee (percentage)
        uint256 platformFee = _calculatePlatformFee(deal.amount);
        
        // Enforce minimum fee ($10 USD)
        if (deal.creationPriceUSD > 0) {
            // ===== ETH: Use creation time price =====
            // Calculate fee USD value using CREATION time price
            uint256 feeUSD = (platformFee * deal.creationPriceUSD) / 1e18;
            
            // If fee < $10, adjust to minimum
            if (feeUSD < MIN_FEE_USD) {
                // Calculate minimum fee in ETH: ($10 * 1e18) / price
                platformFee = (MIN_FEE_USD * 1e18) / deal.creationPriceUSD;
            }
            
        } else {
            // ===== Stablecoin: 1:1 USD =====
            // Get stablecoin decimals for dynamic conversion
            StablecoinInfo memory stablecoin = stablecoins[deal.token];
            
            // Convert fee to USD (token decimals → 8 decimals)
            uint256 feeUSD;
            if (stablecoin.decimals <= 8) {
                feeUSD = platformFee * (10 ** (8 - stablecoin.decimals));
            } else {
                feeUSD = platformFee / (10 ** (stablecoin.decimals - 8));
            }
            
            // If fee < $10, adjust to minimum
            if (feeUSD < MIN_FEE_USD) {
                // Convert $10 (8 decimals) to token decimals
                if (stablecoin.decimals <= 8) {
                    platformFee = MIN_FEE_USD / (10 ** (8 - stablecoin.decimals));
                } else {
                    platformFee = MIN_FEE_USD * (10 ** (stablecoin.decimals - 8));
                }
            }
        }
        
        uint256 arbiterFee = 0;
        
        // Charge arbiter fee only if disputed
        if (deal.status == DealStatus.Resolved) {
            // Use the arbiter's individual fee rate stored in the deal
            arbiterFee = (deal.amount * deal.arbiterFeeBps) / 10000;
            
            // Enforce minimum arbiter fee ($5 USD)
            if (deal.creationPriceUSD > 0) {
                // ===== ETH: Use creation time price =====
                // Calculate arbiter fee USD value using CREATION time price
                uint256 arbiterFeeUSD = (arbiterFee * deal.creationPriceUSD) / 1e18;
                
                // If fee < $5, adjust to minimum
                if (arbiterFeeUSD < MIN_ARBITER_FEE_USD) {
                    // Calculate minimum fee in ETH: ($5 * 1e18) / price
                    arbiterFee = (MIN_ARBITER_FEE_USD * 1e18) / deal.creationPriceUSD;
                }
                
            } else {
                // ===== Stablecoin: 1:1 USD =====
                // Get stablecoin decimals for dynamic conversion
                StablecoinInfo memory stablecoin = stablecoins[deal.token];
                
                // Convert arbiter fee to USD (token decimals → 8 decimals)
                uint256 arbiterFeeUSD;
                if (stablecoin.decimals <= 8) {
                    arbiterFeeUSD = arbiterFee * (10 ** (8 - stablecoin.decimals));
                } else {
                    arbiterFeeUSD = arbiterFee / (10 ** (stablecoin.decimals - 8));
                }
                
                // If fee < $5, adjust to minimum
                if (arbiterFeeUSD < MIN_ARBITER_FEE_USD) {
                    // Convert $5 (8 decimals) to token decimals
                    if (stablecoin.decimals <= 8) {
                        arbiterFee = MIN_ARBITER_FEE_USD / (10 ** (8 - stablecoin.decimals));
                    } else {
                        arbiterFee = MIN_ARBITER_FEE_USD * (10 ** (stablecoin.decimals - 8));
                    }
                }
            }
        }
        
        uint256 netAmount = deal.amount - platformFee - arbiterFee;
        
        // Accumulate platform fee in contract (gas optimization)
        accumulatedFees[deal.token] += platformFee;
        
        // Send arbiter fee if applicable
        if (arbiterFee > 0 && deal.arbiter != address(0)) {
            _transferFunds(deal.token, deal.arbiter, arbiterFee);
        }
        
        // Distribute net amount
        if (buyerRatio == 100) {
            // Full refund to buyer or single recipient
            address recipient = primaryRecipient != address(0) ? primaryRecipient : deal.buyer;
            _transferFunds(deal.token, recipient, netAmount);
        } else if (sellerRatio == 100) {
            // Full payment to seller
            _transferFunds(deal.token, deal.seller, netAmount);
        } else {
            // Split according to ratio
            uint256 buyerAmount = (netAmount * buyerRatio) / 100;
            uint256 sellerAmount = netAmount - buyerAmount;
            
            if (buyerAmount > 0) {
                _transferFunds(deal.token, deal.buyer, buyerAmount);
            }
            
            if (sellerAmount > 0) {
                _transferFunds(deal.token, deal.seller, sellerAmount);
            }
        }
    }
    
    /**
     * @notice Transfers funds (ETH or ERC20)
     * @param token Token address (address(0) for ETH)
     * @param to Recipient address
     * @param amount Amount to transfer
     */
    function _transferFunds(address token, address to, uint256 amount) internal {
        if (amount == 0) return;
        
        if (token == address(0)) {
            // Transfer ETH
            (bool success, ) = to.call{value: amount}("");
            require(success, "ETH transfer failed");
        } else {
            // Transfer ERC20
            IERC20(token).safeTransfer(to, amount);
        }
    }
    
    /**
     * @notice Closes a deal and releases storage
     * @param dealId Deal identifier
     * @dev Deletes storage to get gas refund and prevent state bloat
     * @dev All events are preserved on-chain for audit trail
     */
    function _closeDeal(uint256 dealId) internal {        
        // Release storage to get gas refund (~15,000 gas)
        delete _deals[dealId];
        delete _resolutions[dealId];
        
        // Note: Events are preserved on-chain for historical audit
        // Storage cleanup doesn't affect event-based data retrieval
    }
    
    // ============ Admin Functions ============
    
    /**
     * @notice Adds a stablecoin to the supported list
     * @param token Stablecoin address (USDT, USDC, DAI, etc.)
     * @param decimals Token decimals (6 for USDT/USDC, 18 for DAI)
     * @dev Only admin can add stablecoins. Each stablecoin is assumed to be 1:1 USD pegged
     */
    function addStablecoin(address token, uint8 decimals) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(token != address(0), "Invalid token address");
        require(decimals > 0 && decimals <= 18, "Invalid decimals");
        require(!stablecoins[token].isActive, "Stablecoin already exists");
        
        stablecoins[token] = StablecoinInfo({
            isActive: true,
            decimals: decimals
        });
        
        stablecoinList.push(token);
    }
    
    /**
     * @notice Removes a stablecoin from the supported list
     * @param token Stablecoin address to remove
     * @dev Only admin can remove. This will prevent new deals but won't affect existing ones
     */
    function removeStablecoin(address token) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(stablecoins[token].isActive, "Stablecoin not found");
        
        stablecoins[token].isActive = false;
        
        // Remove from array
        for (uint256 i = 0; i < stablecoinList.length; i++) {
            if (stablecoinList[i] == token) {
                stablecoinList[i] = stablecoinList[stablecoinList.length - 1];
                stablecoinList.pop();
                break;
            }
        }
    }
    
    /**
     * @notice Updates a stablecoin's decimals (in case of error correction)
     * @param token Stablecoin address
     * @param decimals New decimals value
     */
    function updateStablecoinDecimals(address token, uint8 decimals) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(stablecoins[token].isActive, "Stablecoin not found");
        require(decimals > 0 && decimals <= 18, "Invalid decimals");
        
        stablecoins[token].decimals = decimals;
    }
    
    // ============ Fee Management (Admin) ============
    
    /**
     * @notice Update default platform fee rate
     */
    function updatePlatformFee(uint16 newFeeBps) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (newFeeBps > MAX_FEE_BPS) revert InvalidFee();
        defaultPlatformFeeBps = newFeeBps;
    }
    
    /**
     * @notice Update default arbiter fee rate
     * @dev This is the default rate for new arbiters and non-pre-selected arbiters
     */
    function updateDefaultArbiterFee(uint16 newFeeBps) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (newFeeBps > MAX_FEE_BPS) revert InvalidFee();
        defaultArbiterFeeBps = newFeeBps;
    }
    
    // ============ Arbitration Management (Admin) ============
    
    /**
     * @notice Register a new arbiter
     */
    function registerArbiter(address arbiter) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _registerArbiterInternal(arbiter);
    }
    
    /**
     * @notice Deactivate an arbiter
     */
    function deactivateArbiter(address arbiter) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (arbiters[arbiter].registeredAt == 0) revert ArbiterNotFound();
        arbiters[arbiter].isActive = false;
        _revokeRole(ARBITER_ROLE, arbiter);
    }
    
    /**
     * @notice Activate an arbiter
     */
    function activateArbiter(address arbiter) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (arbiters[arbiter].registeredAt == 0) revert ArbiterNotFound();
        arbiters[arbiter].isActive = true;
        _grantRole(ARBITER_ROLE, arbiter);
    }
    
    /**
     * @notice Remove arbiter from registry
     */
    function removeArbiter(address arbiter) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (arbiters[arbiter].registeredAt == 0) revert ArbiterNotFound();
        require(
            arbiters[arbiter].totalCases == arbiters[arbiter].resolvedCases,
            "Arbiter has pending cases"
        );
        
        // Remove from array
        for (uint256 i = 0; i < arbiterList.length; i++) {
            if (arbiterList[i] == arbiter) {
                arbiterList[i] = arbiterList[arbiterList.length - 1];
                arbiterList.pop();
                break;
            }
        }
        
        _revokeRole(ARBITER_ROLE, arbiter);
        delete arbiters[arbiter];
        emit ArbiterRemoved(arbiter);
    }
    
    /**
     * @notice Update individual arbiter's fee rate
     * @param arbiter Arbiter address
     * @param feeBps New fee rate in basis points (e.g., 100 = 1%, 150 = 1.5%)
     * @dev Allows admin to incentivize good arbiters or penalize poor ones
     */
    function updateArbiterFee(address arbiter, uint16 feeBps) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (arbiters[arbiter].registeredAt == 0) revert ArbiterNotFound();
        if (feeBps > MAX_FEE_BPS) revert InvalidFee();
        
        arbiters[arbiter].arbiterFeeBps = feeBps;
    }
    
    /**
     * @notice Get all arbiters
     */
    function getAllArbiters() external view returns (address[] memory) {
        return arbiterList;
    }
    
    /**
     * @notice Check if arbiter is active
     */
    function isActiveArbiter(address arbiter) external view returns (bool) {
        return _isActiveArbiter(arbiter);
    }
    
    /**
     * @notice Get arbiter information
     */
    function getArbiterInfo(address arbiter) external view returns (ArbiterInfo memory) {
        return arbiters[arbiter];
    }
    
    // ============ Treasury Management (Admin) ============
    
    /**
     * @notice Update withdrawal address
     */
    function updateWithdrawalAddress(address newAddress) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(newAddress != address(0), "Invalid address");
        withdrawalAddress = newAddress;
    }
    
    // ============ Price Oracle Management (Admin) ============
    
    /**
     * @notice Update Chainlink price feed
     */
    function updatePriceFeed(address newFeed) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(newFeed != address(0), "Invalid address");
        ethUsdPriceFeed = AggregatorV3Interface(newFeed);
    }
    
    /**
     * @notice Manually set cached price (for testnet/emergencies)
     */
    function setManualPrice(uint256 price) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (price == 0) revert InvalidPrice();
        cachedEthPrice = price;
        priceCacheTime = block.timestamp;
    }
    
    /**
     * @notice Get current cached price
     */
    function getCachedPrice() external view returns (uint256 price, uint256 timestamp) {
        return (cachedEthPrice, priceCacheTime);
    }
    
    // ============ Emergency Controls ============
    
    /**
     * @notice Pauses the contract
     */
    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }
    
    /**
     * @notice Unpauses the contract
     */
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }
    
    // ============ View Functions ============
    
    /**
     * @notice Gets deal information
     * @param dealId Deal identifier
     * @return Deal struct
     */
    function getDeal(uint256 dealId) external view override returns (Deal memory) {
        return _deals[dealId];
    }
    
    /**
     * @notice Gets dispute resolution information
     * @param dealId Deal identifier
     * @return DisputeResolution struct
     */
    function getDisputeResolution(uint256 dealId) 
        external 
        view 
        override 
        returns (DisputeResolution memory) 
    {
        return _resolutions[dealId];
    }
    
    /**
     * @notice Gets the highest deal ID ever created
     * @return Last deal ID (continuously incrementing, never decreases)
     * @dev This is the max dealId, not active deal count
     * @dev Deal IDs increment forever: 1, 2, 3, ... even if some deals are closed
     * @dev For backend: Use this as unique identifier sequence
     */
    function dealCount() external view override returns (uint256) {
        return _dealIdCounter - 1;
    }
    
    /**
     * @notice Checks if token is supported
     * @param token Token address (address(0) for ETH)
     * @return True if supported
     * @dev ETH is always supported. ERC20 tokens must be registered stablecoins
     */
    function isTokenWhitelisted(address token) external view override returns (bool) {
        if (token == address(0)) {
            return true; // ETH is always supported
        }
        return stablecoins[token].isActive;
    }
    
    /**
     * @notice Gets all supported stablecoins
     * @return Array of stablecoin addresses
     */
    function getSupportedStablecoins() external view returns (address[] memory) {
        return stablecoinList;
    }
    
    /**
     * @notice Gets stablecoin info
     * @param token Stablecoin address
     * @return info Stablecoin configuration
     */
    function getStablecoinInfo(address token) external view returns (StablecoinInfo memory info) {
        return stablecoins[token];
    }
    
    /**
     * @notice Gets contract version
     * @return Version string
     */
    function version() external pure returns (string memory) {
        return "1.0.3";
    }
    
    // ============ Fee Management ============
    
    /**
     * @notice Withdraws accumulated platform fees
     * @dev Only admin can withdraw fees
     * @dev Fees are withdrawn to the treasury contract
     * @param token Token address (address(0) for ETH)
     * @param amount Amount to withdraw (0 to withdraw all)
     */
    function withdrawFees(address token, uint256 amount) 
        external 
        onlyRole(DEFAULT_ADMIN_ROLE) 
        nonReentrant 
    {
        uint256 available = accumulatedFees[token];
        require(available > 0, "No fees to withdraw");
        
        // If amount is 0, withdraw all
        uint256 withdrawAmount = amount == 0 ? available : amount;
        require(withdrawAmount <= available, "Insufficient fees");
        
        // Update state
        accumulatedFees[token] -= withdrawAmount;
        
        // Transfer to withdrawal address
        _transferFunds(token, withdrawalAddress, withdrawAmount);
        
        emit FeeWithdrawn(token, withdrawalAddress, withdrawAmount);
    }
    
    
    /**
     * @notice Gets accumulated platform fees for a token
     * @param token Token address (address(0) for ETH)
     * @return Accumulated fee amount
     */
    function getAccumulatedFees(address token) external view returns (uint256) {
        return accumulatedFees[token];
    }
    
    // ============================================================
    // INTEGRATED INTERNAL FUNCTIONS
    // ============================================================
    
    // -------- Fee Management Functions --------
    
    /**
     * @notice Calculate platform fee for given amount
     */
    function _calculatePlatformFee(uint256 amount) internal view returns (uint256) {
        uint16 feeBps = _getPlatformFeeBps(amount);
        return (amount * feeBps) / 10000;
    }
    
    /**
     * @notice Get platform fee rate in basis points
     */
    function _getPlatformFeeBps(uint256 /* amount */) internal view returns (uint16) {
        // Simplified: no tiers, just default rate
        return defaultPlatformFeeBps;
    }
    
    // -------- Arbitration Functions --------
    
    /**
     * @notice Check if address is active arbiter
     */
    function _isActiveArbiter(address arbiter) internal view returns (bool) {
        return arbiters[arbiter].isActive && arbiters[arbiter].registeredAt != 0;
    }
    
    /**
     * @notice Internal arbiter registration
     */
    function _registerArbiterInternal(address arbiter) internal {
        if (arbiter == address(0)) revert ArbiterNotFound();
        if (arbiters[arbiter].registeredAt != 0) revert ArbiterAlreadyExists();
        
        arbiters[arbiter] = ArbiterInfo({
            isActive: true,
            totalCases: 0,
            resolvedCases: 0,
            reputation: 80, // Default reputation
            arbiterFeeBps: defaultArbiterFeeBps, // Use default fee rate initially
            registeredAt: uint64(block.timestamp)
        });
        
        arbiterList.push(arbiter);
        _grantRole(ARBITER_ROLE, arbiter);
        
        emit ArbiterRegistered(arbiter, uint64(block.timestamp));
    }
    
    /**
     * @notice Select random arbiter from active list
     */
    function _selectRandomArbiter() internal view returns (address) {
        uint256 activeCount = 0;
        for (uint256 i = 0; i < arbiterList.length; i++) {
            if (arbiters[arbiterList[i]].isActive) {
                activeCount++;
            }
        }
        
        require(activeCount > 0, "No active arbiters");
        
        // Simple pseudo-random selection
        uint256 randomIndex = uint256(keccak256(abi.encodePacked(
            block.timestamp,
            block.prevrandao,
            msg.sender
        ))) % activeCount;
        
        uint256 currentIndex = 0;
        for (uint256 i = 0; i < arbiterList.length; i++) {
            if (arbiters[arbiterList[i]].isActive) {
                if (currentIndex == randomIndex) {
                    return arbiterList[i];
                }
                currentIndex++;
            }
        }
        
        revert("Arbiter selection failed");
    }
    
    /**
     * @notice Register dispute (update arbiter stats)
     */
    function _registerDispute(uint256 /* dealId */, address /* initiator */, address arbiter) internal {
        arbiters[arbiter].totalCases++;
    }
    
    /**
     * @notice Mark dispute as resolved (update arbiter stats)
     */
    function _resolveDisputeRecord(address arbiter) internal {
        arbiters[arbiter].resolvedCases++;
    }
    
    // -------- Price Oracle Functions --------
    
    /**
     * @notice Get ETH price in USD (8 decimals) with caching
     */
    function _getEthPriceUSD() internal returns (uint256) {
        // Check cache validity (10 minutes)
        if (priceCacheTime > 0 && block.timestamp - priceCacheTime < PRICE_CACHE_DURATION) {
            return cachedEthPrice;
        }
        
        // Fetch fresh price from Chainlink
        uint256 freshPrice = _fetchEthPriceFromChainlink();
        
        // Update cache
        cachedEthPrice = freshPrice;
        priceCacheTime = block.timestamp;
        
        return freshPrice;
    }
    
    /**
     * @notice Fetch ETH price from Chainlink
     */
    function _fetchEthPriceFromChainlink() internal view returns (uint256) {
        if (address(ethUsdPriceFeed) == address(0)) {
            // Fallback to manual price if no feed set
            return cachedEthPrice > 0 ? cachedEthPrice : 2500_0000_0000; // $2500 default
        }
        
        try ethUsdPriceFeed.latestRoundData() returns (
            uint80 /* roundId */,
            int256 price,
            uint256 /* startedAt */,
            uint256 updatedAt,
            uint80 /* answeredInRound */
        ) {
            require(price > 0, "Invalid price from feed");
            require(updatedAt > 0, "Price data is stale");
            require(block.timestamp - updatedAt < 1 hours, "Price too old");
            
            // Chainlink returns 8 decimals for ETH/USD
            return uint256(price);
        } catch {
            revert InvalidPrice();
        }
    }
    
    /**
     * @notice Convert amount to USD (8 decimals)
     */
    function _convertToUSD(uint256 amount, uint8 decimals) internal pure returns (uint256) {
        if (decimals <= 8) {
            return amount * (10 ** (8 - decimals));
        } else {
            return amount / (10 ** (decimals - 8));
        }
    }
    
    // ============ Receive ETH ============
    
    /**
     * @notice Rejects direct ETH transfers
     * @dev Users must use createDealETH() to create deals
     * @dev Prevents accidental fund loss from direct transfers
     */
    receive() external payable {
        revert("Use createDealETH() to create deals");
    }
    
    /**
     * @notice Rejects calls to undefined functions
     * @dev Prevents accidental fund loss
     */
    fallback() external payable {
        revert("Function not found. Use createDealETH() for deals");
    }
}

