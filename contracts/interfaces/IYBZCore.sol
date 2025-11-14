// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title IYBZCore
 * @notice Interface for YBZ Escrow Core Contract
 * @dev Defines the core escrow functionality and data structures
 */
interface IYBZCore {
    
    /// @notice Deal lifecycle status
    enum DealStatus {
        Created,      // Deal created, waiting for seller acceptance
        Accepted,     // Seller accepted, waiting for work submission
        Submitted,    // Work submitted, waiting for buyer confirmation
        Disputed,     // Dispute raised, waiting for arbitration
        Approved,     // Deal approved, funds released
        Cancelled,    // Deal cancelled (timeout or manual cancellation)
        Resolved,     // Dispute resolved by arbitrator
        Closed        // Deal completed and storage cleaned
    }
    
    /// @notice Main deal structure
    struct Deal {
        address buyer;                  // Buyer address
        address seller;                 // Seller address
        address token;                  // Token address (address(0) for ETH)
        uint256 amount;                 // Total amount locked
        uint256 creationPriceUSD;       // Token price in USD at creation (8 decimals, for ETH only)
        uint16 platformFeeBps;          // Platform fee in basis points
        uint16 arbiterFeeBps;           // Arbiter fee in basis points (only charged if disputed)
        bytes32 termsHash;              // IPFS hash of deal terms
        bytes32 deliveryHash;           // IPFS hash of delivery proof
        uint64 acceptDeadline;          // Deadline for seller to accept
        uint64 submitDeadline;          // Deadline for seller to submit work
        uint64 confirmDeadline;         // Deadline for buyer to confirm (recalculated on submission)
        uint64 acceptWindow;            // Time window for accept (stored for reference)
        uint64 submitWindow;            // Time window for submit (stored for reference)
        uint64 confirmWindow;           // Time window for confirm (used to recalculate deadline)
        uint64 createdAt;               // Creation timestamp
        uint64 submittedAt;             // Work submission timestamp (0 if not submitted)
        address arbiter;                // Assigned arbiter address
        DealStatus status;              // Current deal status
        bool refundRequested;           // Buyer requested mutual refund
        // Deadline proposal fields
        uint64 proposedSubmitWindow;    // Proposed new submit window
        uint64 proposedConfirmWindow;   // Proposed new confirm window
        address proposedBy;             // Who proposed the change
        bool proposalAccepted;          // Whether proposal was accepted
    }
    
    /// @notice Dispute resolution data
    struct DisputeResolution {
        address arbiter;                // Arbiter who resolved the dispute
        uint8 buyerRatio;               // Percentage to buyer (0-100)
        uint8 sellerRatio;              // Percentage to seller (0-100)
        bytes32 evidenceHash;           // IPFS hash of arbitration evidence
        uint64 resolvedAt;              // Resolution timestamp
        uint256 arbiterFee;             // Fee paid to arbiter
    }
    
    // ============ Events ============
    
    event DealCreated(
        uint256 indexed dealId,
        address indexed buyer,
        address indexed seller,
        address token,
        uint256 amount,
        uint256 creationPriceUSD,
        uint16 platformFeeBps,
        uint16 arbiterFeeBps,
        bytes32 termsHash,
        uint64 acceptWindow,
        uint64 submitWindow,
        uint64 confirmWindow,
        address preferredArbiter,
        string platform
    );
    
    event DealAccepted(
        uint256 indexed dealId,
        address indexed seller,
        uint64 submitDeadline
    );
    
    event WorkSubmitted(
        uint256 indexed dealId,
        bytes32 deliveryHash,
        uint64 confirmDeadline
    );
    
    event DealApproved(
        uint256 indexed dealId,
        address indexed seller,
        uint256 amount
    );
    
    event DisputeRaised(
        uint256 indexed dealId,
        address indexed initiator,
        bytes32 evidenceHash
    );
    
    event DisputeResolved(
        uint256 indexed dealId,
        address indexed arbiter,
        uint8 buyerRatio,
        uint8 sellerRatio,
        bytes32 evidenceHash
    );
    
    event DealCancelled(
        uint256 indexed dealId,
        address indexed initiator,
        string reason
    );
    
    event DealFinalized(
        uint256 indexed dealId,
        address indexed recipient,
        address indexed initiator,
        uint256 amount,
        DealStatus finalStatus,
        string platform,
        string reason
    );
    
    event RefundRequested(
        uint256 indexed dealId,
        address indexed buyer
    );
    
    event DeadlineProposed(
        uint256 indexed dealId,
        address indexed proposer,
        uint64 newSubmitWindow,
        uint64 newConfirmWindow
    );
    
    event DeadlineUpdated(
        uint256 indexed dealId,
        uint64 submitWindow,
        uint64 confirmWindow,
        address indexed acceptedBy
    );
    
    event DealRejected(
        uint256 indexed dealId,
        address indexed seller
    );
    
    // ============ Core Functions ============
    
    function createDealETH(
        address seller,
        bytes32 termsHash,
        uint64 acceptWindow,
        uint64 submitWindow,
        uint64 confirmWindow,
        address preferredArbiter
    ) external payable returns (uint256 dealId);
    
    function createDealERC20(
        address seller,
        address token,
        uint256 amount,
        bytes32 termsHash,
        uint64 acceptWindow,
        uint64 submitWindow,
        uint64 confirmWindow,
        address preferredArbiter
    ) external returns (uint256 dealId);
    
    function acceptDeal(uint256 dealId) external;
    
    function rejectDeal(uint256 dealId) external;
    
    function submitWork(uint256 dealId, bytes32 deliveryHash) external;
    
    function approveDeal(uint256 dealId) external;
    
    function raiseDispute(uint256 dealId, bytes32 evidenceHash) external;
    
    function resolveDispute(
        uint256 dealId,
        uint8 buyerRatio,
        uint8 sellerRatio,
        bytes32 evidenceHash
    ) external;
    
    function autoCancel(uint256 dealId) external;
    
    function cancelDeal(uint256 dealId) external;
    
    function autoRefund(uint256 dealId) external;
    
    function requestRefund(uint256 dealId) external;
    
    function approveRefund(uint256 dealId) external;
    
    function autoRelease(uint256 dealId) external;
    
    function emergencyRelease(uint256 dealId) external;
    
    // ============ Deadline Management ============
    
    function proposeNewDeadline(
        uint256 dealId,
        uint64 newSubmitWindow,
        uint64 newConfirmWindow
    ) external;
    
    function acceptDeadlineProposal(uint256 dealId) external;
    
    // ============ View Functions ============
    
    function getDeal(uint256 dealId) external view returns (Deal memory);
    
    function getDisputeResolution(uint256 dealId) external view returns (DisputeResolution memory);
    
    function dealCount() external view returns (uint256);
    
    function isTokenWhitelisted(address token) external view returns (bool);
}

