// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../interfaces/IYBZCore.sol";

/**
 * @title DealValidation
 * @notice Library for deal validation and state transition checks
 * @dev Gas-optimized validation logic extracted to library
 */
library DealValidation {
    
    /// @notice Minimum time windows (in seconds)
    /// @dev Flexible limits to accommodate various industries
    uint64 public constant MIN_ACCEPT_WINDOW = 1 hours;     // Min: 1 hour (quick response)
    uint64 public constant MIN_SUBMIT_WINDOW = 1 hours;     // Min: 1 hour (small tasks like translation)
    uint64 public constant MIN_CONFIRM_WINDOW = 1 hours;    // Min: 1 hour (quick verification)
    
    /// @notice Maximum time windows (in seconds)
    /// @dev Max limits prevent indefinite locks
    uint64 public constant MAX_ACCEPT_WINDOW = 30 days;     // Max: 30 days
    uint64 public constant MAX_SUBMIT_WINDOW = 180 days;    // Max: 6 months (supply chain, custom manufacturing)
    uint64 public constant MAX_CONFIRM_WINDOW = 30 days;    // Max: 30 days
    
    /// @notice Minimum deal amount (to prevent spam)
    uint256 public constant MIN_DEAL_AMOUNT = 0.001 ether;
    
    /// @notice Maximum fee in basis points (10%)
    uint16 public constant MAX_FEE_BPS = 1000;
    
    // ============ Errors ============
    
    error InvalidAmount();
    error InvalidAddress();
    error InvalidTimeWindow();
    error InvalidTermsHash();
    error InvalidStatus(IYBZCore.DealStatus current, IYBZCore.DealStatus required);
    error Unauthorized();
    error DeadlinePassed();
    error DeadlineNotReached();
    error InvalidRatio();
    
    // ============ Validation Functions ============
    
    /**
     * @notice Validates deal creation parameters
     * @param seller Seller address
     * @param amount Deal amount
     * @param termsHash Terms hash
     * @param acceptWindow Accept time window
     * @param submitWindow Submit time window
     * @param confirmWindow Confirm time window
     */
    function validateCreateDeal(
        address seller,
        uint256 amount,
        bytes32 termsHash,
        uint64 acceptWindow,
        uint64 submitWindow,
        uint64 confirmWindow
    ) internal pure {
        if (seller == address(0)) revert InvalidAddress();
        if (amount < MIN_DEAL_AMOUNT) revert InvalidAmount();
        if (termsHash == bytes32(0)) revert InvalidTermsHash();
        
        if (acceptWindow < MIN_ACCEPT_WINDOW || acceptWindow > MAX_ACCEPT_WINDOW) {
            revert InvalidTimeWindow();
        }
        if (submitWindow < MIN_SUBMIT_WINDOW || submitWindow > MAX_SUBMIT_WINDOW) {
            revert InvalidTimeWindow();
        }
        if (confirmWindow < MIN_CONFIRM_WINDOW || confirmWindow > MAX_CONFIRM_WINDOW) {
            revert InvalidTimeWindow();
        }
    }
    
    /**
     * @notice Validates state transition
     * @param currentStatus Current deal status
     * @param requiredStatus Required status for operation
     */
    function requireStatus(
        IYBZCore.DealStatus currentStatus,
        IYBZCore.DealStatus requiredStatus
    ) internal pure {
        if (currentStatus != requiredStatus) {
            revert InvalidStatus(currentStatus, requiredStatus);
        }
    }
    
    /**
     * @notice Checks if caller is authorized for the deal
     * @param deal Deal struct
     * @param caller Caller address
     * @param isBuyerRequired True if buyer authorization required
     */
    function requireAuthorized(
        IYBZCore.Deal memory deal,
        address caller,
        bool isBuyerRequired
    ) internal pure {
        address authorized = isBuyerRequired ? deal.buyer : deal.seller;
        if (caller != authorized) revert Unauthorized();
    }
    
    /**
     * @notice Checks if deadline has passed
     * @param deadline Deadline timestamp
     */
    function requireDeadlinePassed(uint64 deadline) internal view {
        if (block.timestamp <= deadline) revert DeadlineNotReached();
    }
    
    /**
     * @notice Checks if deadline has not passed
     * @param deadline Deadline timestamp
     */
    function requireDeadlineNotPassed(uint64 deadline) internal view {
        if (block.timestamp > deadline) revert DeadlinePassed();
    }
    
    /**
     * @notice Validates dispute resolution ratios
     * @param buyerRatio Buyer ratio (0-100)
     * @param sellerRatio Seller ratio (0-100)
     */
    function validateResolutionRatio(
        uint8 buyerRatio,
        uint8 sellerRatio
    ) internal pure {
        if (buyerRatio + sellerRatio != 100) revert InvalidRatio();
    }
    
    /**
     * @notice Checks if deal can be auto-cancelled (Created status only)
     * @param deal Deal struct
     * @dev Now only for Created status, Accepted uses cancelDeal()
     */
    function canAutoCancel(IYBZCore.Deal memory deal) internal view returns (bool) {
        // Can auto-cancel if Created and accept deadline passed
        return deal.status == IYBZCore.DealStatus.Created && 
               block.timestamp > deal.acceptDeadline;
    }
    
    /**
     * @notice Checks if deal can be auto-released
     * @param deal Deal struct
     */
    function canAutoRelease(IYBZCore.Deal memory deal) internal view returns (bool) {
        return deal.status == IYBZCore.DealStatus.Submitted && 
               block.timestamp > deal.confirmDeadline;
    }
}

