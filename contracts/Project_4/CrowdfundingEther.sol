// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title CrowdfundingEther
 * @notice A secure crowdfunding contract that accepts Ether
 * @dev Implements all security best practices including reentrancy protection and CEI pattern
 */
contract CrowdfundingEther is ReentrancyGuard {
    
    // ============ State Variables ============
    
    uint256 private _nextFundraiserId;
    uint256 private _nextDonationId;
    
    // Grace period for donors to withdraw if creator doesn't claim (30 days)
    uint256 public constant GRACE_PERIOD = 30 days;
    
    // ============ Enums ============
    
    enum FundraiserStatus {
        Ongoing,
        Successful,
        Cancelled,
        Failed
    }
    
    // ============ Structs ============
    
    struct Fundraiser {
        address payable creator;
        uint256 goal;
        uint256 currentFund;
        uint256 deadline;
        FundraiserStatus status;
        uint256 createdAt;
    }
    
    struct Donation {
        uint256 amount;
        bool withdrawn;
        uint256 timestamp;
    }
    
    // ============ Mappings ============
    
    mapping(uint256 => Fundraiser) public fundraisers;
    mapping(address => mapping(uint256 => bool)) public hasDonatedToFund;
    mapping(address => mapping(uint256 => uint256)) public donationIdsFromFund;
    mapping(uint256 => Donation) public donations;
    
    // ============ Events ============
    
    event FundraiserCreated(
        uint256 indexed fundraiserId,
        address indexed creator,
        uint256 goal,
        uint256 deadline,
        uint256 timestamp
    );
    
    event DonatedToFundraiser(
        address indexed donor,
        uint256 indexed fundraiserId,
        uint256 indexed donationId,
        uint256 amount,
        uint256 timestamp
    );
    
    event FundsWithdrawn(
        address indexed creator,
        uint256 indexed fundraiserId,
        uint256 amount,
        uint256 timestamp
    );
    
    event DonationWithdrawn(
        address indexed donor,
        uint256 indexed fundraiserId,
        uint256 indexed donationId,
        uint256 amount,
        uint256 timestamp
    );
    
    event FundraiserCancelled(
        uint256 indexed fundraiserId,
        address indexed creator,
        uint256 timestamp
    );
    
    event FundraiserStatusChanged(
        uint256 indexed fundraiserId,
        FundraiserStatus newStatus,
        uint256 timestamp
    );
    
    // ============ Errors ============
    
    error InvalidGoal();
    error InvalidDeadline();
    error InvalidFundraiser();
    error InvalidAmount();
    error DeadlinePassed();
    error NotTheCreator();
    error FundraiserNotOngoing();
    error GoalNotReached();
    error HasNotDonated();
    error AlreadyWithdrawn();
    error FundraiserLocked();
    error GoalAlreadyReached();
    error TransferFailed();
    error CannotWithdrawYet();
    
    // ============ Modifiers ============
    
    modifier fundraiserExists(uint256 _fundraiserId) {
        if (fundraisers[_fundraiserId].creator == address(0)) {
            revert InvalidFundraiser();
        }
        _;
    }
    
    modifier onlyCreator(uint256 _fundraiserId) {
        if (fundraisers[_fundraiserId].creator != msg.sender) {
            revert NotTheCreator();
        }
        _;
    }
    
    // ============ Functions ============
    
    /**
     * @notice Creates a new fundraiser campaign
     * @param _goal The funding goal in wei
     * @param _deadlineInDays The deadline in days from now
     * @return fundraiserId The ID of the created fundraiser
     */
    function createFundraiser(
        uint256 _goal,
        uint256 _deadlineInDays
    ) external returns (uint256 fundraiserId) {
        if (_goal == 0) revert InvalidGoal();
        if (_deadlineInDays == 0) revert InvalidDeadline();
        
        fundraiserId = _nextFundraiserId++;
        
        uint256 deadline = block.timestamp + (_deadlineInDays * 1 days);
        
        fundraisers[fundraiserId] = Fundraiser({
            creator: payable(msg.sender),
            goal: _goal,
            currentFund: 0,
            deadline: deadline,
            status: FundraiserStatus.Ongoing,
            createdAt: block.timestamp
        });
        
        emit FundraiserCreated(
            fundraiserId,
            msg.sender,
            _goal,
            deadline,
            block.timestamp
        );
    }
    
    /**
     * @notice Donate Ether to a fundraiser
     * @param _fundraiserId The ID of the fundraiser to donate to
     */
    function donate(uint256 _fundraiserId) 
        external 
        payable 
        nonReentrant 
        fundraiserExists(_fundraiserId) 
    {
        if (msg.value == 0) revert InvalidAmount();
        
        Fundraiser storage fundraiser = fundraisers[_fundraiserId];
        
        // Cache storage values
        uint256 deadline = fundraiser.deadline;
        FundraiserStatus status = fundraiser.status;
        
        if (block.timestamp > deadline) revert DeadlinePassed();
        if (status != FundraiserStatus.Ongoing) revert FundraiserNotOngoing();
        
        // Handle first-time or repeat donor
        if (!hasDonatedToFund[msg.sender][_fundraiserId]) {
            // First time donor
            uint256 donationId = _nextDonationId++;
            
            donations[donationId] = Donation({
                amount: msg.value,
                withdrawn: false,
                timestamp: block.timestamp
            });
            
            donationIdsFromFund[msg.sender][_fundraiserId] = donationId;
            hasDonatedToFund[msg.sender][_fundraiserId] = true;
            
            emit DonatedToFundraiser(
                msg.sender,
                _fundraiserId,
                donationId,
                msg.value,
                block.timestamp
            );
        } else {
            // Repeat donor - update existing donation
            uint256 donationId = donationIdsFromFund[msg.sender][_fundraiserId];
            Donation storage donation = donations[donationId];
            
            donation.amount += msg.value;
            donation.timestamp = block.timestamp;
            
            emit DonatedToFundraiser(
                msg.sender,
                _fundraiserId,
                donationId,
                msg.value,
                block.timestamp
            );
        }
        
        // Update fundraiser's current fund
        fundraiser.currentFund += msg.value;
    }
    
    /**
     * @notice Allows creator to withdraw funds if goal is reached
     * @param _fundraiserId The ID of the fundraiser
     */
    function withdrawFunds(uint256 _fundraiserId)
        external
        nonReentrant
        fundraiserExists(_fundraiserId)
        onlyCreator(_fundraiserId)
    {
        Fundraiser storage fundraiser = fundraisers[_fundraiserId];
        
        // Cache storage values for gas optimization
        uint256 currentFund = fundraiser.currentFund;
        uint256 goal = fundraiser.goal;
        FundraiserStatus status = fundraiser.status;
        
        // CHECKS
        if (status != FundraiserStatus.Ongoing) revert FundraiserNotOngoing();
        if (currentFund < goal) revert GoalNotReached();
        
        uint256 amountToSend = currentFund;
        
        // EFFECTS - Update state before external call
        fundraiser.status = FundraiserStatus.Successful;
        fundraiser.currentFund = 0;
        
        emit FundsWithdrawn(msg.sender, _fundraiserId, amountToSend, block.timestamp);
        emit FundraiserStatusChanged(_fundraiserId, FundraiserStatus.Successful, block.timestamp);
        
        // INTERACTIONS - External call last
        (bool success, ) = msg.sender.call{value: amountToSend}("");
        if (!success) revert TransferFailed();
    }
    
    /**
     * @notice Allows donors to withdraw their donation if fundraiser fails
     * @param _fundraiserId The ID of the fundraiser
     */
    function withdrawDonation(uint256 _fundraiserId)
        external
        nonReentrant
        fundraiserExists(_fundraiserId)
    {
        if (!hasDonatedToFund[msg.sender][_fundraiserId]) {
            revert HasNotDonated();
        }
        
        Fundraiser storage fundraiser = fundraisers[_fundraiserId];
        uint256 donationId = donationIdsFromFund[msg.sender][_fundraiserId];
        Donation storage donation = donations[donationId];
        
        // Cache values
        uint256 deadline = fundraiser.deadline;
        uint256 currentFund = fundraiser.currentFund;
        uint256 goal = fundraiser.goal;
        FundraiserStatus status = fundraiser.status;
        bool isWithdrawn = donation.withdrawn;
        uint256 donationAmount = donation.amount;
        
        // CHECKS
        if (isWithdrawn) revert AlreadyWithdrawn();
        if (donationAmount == 0) revert InvalidAmount();
        
        // Determine if withdrawal is allowed
        bool canWithdraw = false;
        
        // Case 1: Fundraiser was cancelled by creator
        if (status == FundraiserStatus.Cancelled) {
            canWithdraw = true;
        }
        // Case 2: Deadline passed and goal not reached
        else if (block.timestamp > deadline && currentFund < goal) {
            canWithdraw = true;
            // Auto-update status to Failed if not already done
            if (status == FundraiserStatus.Ongoing) {
                fundraiser.status = FundraiserStatus.Failed;
                emit FundraiserStatusChanged(_fundraiserId, FundraiserStatus.Failed, block.timestamp);
            }
        }
        // Case 3: Goal reached but creator hasn't withdrawn within grace period
        else if (
            currentFund >= goal && 
            block.timestamp > deadline + GRACE_PERIOD &&
            status == FundraiserStatus.Ongoing
        ) {
            canWithdraw = true;
        }
        
        if (!canWithdraw) revert CannotWithdrawYet();
        
        // EFFECTS - Update state before external call
        donation.withdrawn = true;
        donation.amount = 0;
        fundraiser.currentFund -= donationAmount;
        
        emit DonationWithdrawn(
            msg.sender,
            _fundraiserId,
            donationId,
            donationAmount,
            block.timestamp
        );
        
        // INTERACTIONS - External call last
        (bool success, ) = msg.sender.call{value: donationAmount}("");
        if (!success) revert TransferFailed();
    }
    
    /**
     * @notice Allows creator to cancel the fundraiser
     * @param _fundraiserId The ID of the fundraiser to cancel
     */
    function cancelFundraiser(uint256 _fundraiserId)
        external
        fundraiserExists(_fundraiserId)
        onlyCreator(_fundraiserId)
    {
        Fundraiser storage fundraiser = fundraisers[_fundraiserId];
        
        // Cache values
        FundraiserStatus status = fundraiser.status;
        uint256 currentFund = fundraiser.currentFund;
        uint256 goal = fundraiser.goal;
        
        // CHECKS
        if (status != FundraiserStatus.Ongoing) revert FundraiserNotOngoing();
        if (currentFund >= goal) revert GoalAlreadyReached();
        
        // EFFECTS
        fundraiser.status = FundraiserStatus.Cancelled;
        
        emit FundraiserCancelled(_fundraiserId, msg.sender, block.timestamp);
        emit FundraiserStatusChanged(_fundraiserId, FundraiserStatus.Cancelled, block.timestamp);
    }
    
    // ============ View Functions ============
    
    /**
     * @notice Get fundraiser details
     * @param _fundraiserId The ID of the fundraiser
     * @return Fundraiser details
     */
    function getFundraiser(uint256 _fundraiserId)
        external
        view
        fundraiserExists(_fundraiserId)
        returns (Fundraiser memory)
    {
        return fundraisers[_fundraiserId];
    }
    
    /**
     * @notice Get donation details for a specific donor and fundraiser
     * @param _donor The address of the donor
     * @param _fundraiserId The ID of the fundraiser
     * @return Donation details
     */
    function getDonation(address _donor, uint256 _fundraiserId)
        external
        view
        fundraiserExists(_fundraiserId)
        returns (Donation memory)
    {
        if (!hasDonatedToFund[_donor][_fundraiserId]) {
            revert HasNotDonated();
        }
        uint256 donationId = donationIdsFromFund[_donor][_fundraiserId];
        return donations[donationId];
    }
    
    /**
     * @notice Check if a fundraiser can be withdrawn by creator
     * @param _fundraiserId The ID of the fundraiser
     * @return bool True if creator can withdraw
     */
    function canCreatorWithdraw(uint256 _fundraiserId)
        external
        view
        fundraiserExists(_fundraiserId)
        returns (bool)
    {
        Fundraiser memory fundraiser = fundraisers[_fundraiserId];
        return (
            fundraiser.status == FundraiserStatus.Ongoing &&
            fundraiser.currentFund >= fundraiser.goal
        );
    }
    
    /**
     * @notice Check if a donor can withdraw their donation
     * @param _donor The address of the donor
     * @param _fundraiserId The ID of the fundraiser
     * @return bool True if donor can withdraw
     */
    function canDonorWithdraw(address _donor, uint256 _fundraiserId)
        external
        view
        fundraiserExists(_fundraiserId)
        returns (bool)
    {
        if (!hasDonatedToFund[_donor][_fundraiserId]) {
            return false;
        }
        
        Fundraiser memory fundraiser = fundraisers[_fundraiserId];
        uint256 donationId = donationIdsFromFund[_donor][_fundraiserId];
        Donation memory donation = donations[donationId];
        
        if (donation.withdrawn || donation.amount == 0) {
            return false;
        }
        
        // Check various withdrawal conditions
        if (fundraiser.status == FundraiserStatus.Cancelled) {
            return true;
        }
        
        if (block.timestamp > fundraiser.deadline && fundraiser.currentFund < fundraiser.goal) {
            return true;
        }
        
        if (
            fundraiser.currentFund >= fundraiser.goal &&
            block.timestamp > fundraiser.deadline + GRACE_PERIOD &&
            fundraiser.status == FundraiserStatus.Ongoing
        ) {
            return true;
        }
        
        return false;
    }
    
    /**
     * @notice Get the total number of fundraisers created
     * @return uint256 Total number of fundraisers
     */
    function getTotalFundraisers() external view returns (uint256) {
        return _nextFundraiserId;
    }
    
    /**
     * @notice Get the contract's Ether balance
     * @return uint256 Contract balance in wei
     */
    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }
}