// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {CrowdfundingEther} from "./CrowdfundingEther.sol";

/**
 * @title CrowdfundingEtherTest
 * @notice Test suite for the happy path scenario
 */
contract CrowdfundingEtherTest is Test {
    CrowdfundingEther public crowdfunding;
    
    // Test accounts
    address public creator;
    address public donor1;
    address public donor2;
    address public donor3;
    
    // Test constants
    uint256 public constant INITIAL_BALANCE = 100 ether;
    uint256 public constant GOAL = 10 ether;
    uint256 public constant DEADLINE_DAYS = 30;
    
    // Events to test
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
    
    function setUp() public {
        // Deploy contract
        crowdfunding = new CrowdfundingEther();
        
        // Create test accounts
        creator = makeAddr("creator");
        donor1 = makeAddr("donor1");
        donor2 = makeAddr("donor2");
        donor3 = makeAddr("donor3");
        
        // Fund accounts
        vm.deal(creator, INITIAL_BALANCE);
        vm.deal(donor1, INITIAL_BALANCE);
        vm.deal(donor2, INITIAL_BALANCE);
        vm.deal(donor3, INITIAL_BALANCE);
    }
    
    /**
     * @notice Test the complete happy path:
     * 1. Creator creates a fundraiser
     * 2. Multiple donors donate
     * 3. Goal is reached
     * 4. Creator withdraws funds successfully
     */
    function test_HappyPath_SuccessfulFundraiser() public {
        // ============ STEP 1: Creator creates fundraiser ============
        console.log("\n=== STEP 1: Creating Fundraiser ===");
        
        vm.startPrank(creator);
        
        // Expect FundraiserCreated event
        vm.expectEmit(true, true, false, true);
        emit FundraiserCreated(
            0, // fundraiserId
            creator,
            GOAL,
            block.timestamp + (DEADLINE_DAYS * 1 days),
            block.timestamp
        );
        
        uint256 fundraiserId = crowdfunding.createFundraiser(GOAL, DEADLINE_DAYS);
        
        vm.stopPrank();
        
        // Verify fundraiser was created correctly
        assertEq(fundraiserId, 0, "First fundraiser should have ID 0");
        
        CrowdfundingEther.Fundraiser memory fundraiser = crowdfunding.getFundraiser(fundraiserId);
        assertEq(fundraiser.creator, creator, "Creator should match");
        assertEq(fundraiser.goal, GOAL, "Goal should match");
        assertEq(fundraiser.currentFund, 0, "Initial fund should be 0");
        assertEq(
            fundraiser.deadline, 
            block.timestamp + (DEADLINE_DAYS * 1 days), 
            "Deadline should be 30 days from now"
        );
        assertEq(
            uint256(fundraiser.status), 
            uint256(CrowdfundingEther.FundraiserStatus.Ongoing),
            "Status should be Ongoing"
        );
        
        console.log("Fundraiser created successfully!");
        console.log("Goal:", GOAL / 1 ether, "ETH");
        console.log("Deadline:", DEADLINE_DAYS, "days");
        
        // ============ STEP 2: First donor donates ============
        console.log("\n=== STEP 2: Donor1 Donates ===");
        
        uint256 donation1Amount = 3 ether;
        uint256 donor1BalanceBefore = donor1.balance;
        
        vm.startPrank(donor1);
        
        // Expect DonatedToFundraiser event
        vm.expectEmit(true, true, true, true);
        emit DonatedToFundraiser(
            donor1,
            fundraiserId,
            0, // First donation gets ID 0
            donation1Amount,
            block.timestamp
        );
        
        crowdfunding.donate{value: donation1Amount}(fundraiserId);
        
        vm.stopPrank();
        
        // Verify donation was recorded
        assertEq(
            donor1.balance, 
            donor1BalanceBefore - donation1Amount,
            "Donor1 balance should decrease"
        );
        
        fundraiser = crowdfunding.getFundraiser(fundraiserId);
        assertEq(fundraiser.currentFund, donation1Amount, "Current fund should be 3 ETH");
        
        assertTrue(
            crowdfunding.hasDonatedToFund(donor1, fundraiserId),
            "Donor1 should be marked as donated"
        );
        
        CrowdfundingEther.Donation memory donation1 = crowdfunding.getDonation(donor1, fundraiserId);
        assertEq(donation1.amount, donation1Amount, "Donation amount should match");
        assertFalse(donation1.withdrawn, "Donation should not be withdrawn");
        
        console.log("Donor1 donated:", donation1Amount / 1 ether, "ETH");
        console.log("Current fund:", fundraiser.currentFund / 1 ether, "ETH");
        
        // ============ STEP 3: Same donor donates again ============
        console.log("\n=== STEP 3: Donor1 Donates Again ===");
        
        uint256 donation1SecondAmount = 2 ether;
        
        vm.startPrank(donor1);
        
        crowdfunding.donate{value: donation1SecondAmount}(fundraiserId);
        
        vm.stopPrank();
        
        // Verify the donation was added to existing record
        donation1 = crowdfunding.getDonation(donor1, fundraiserId);
        assertEq(
            donation1.amount, 
            donation1Amount + donation1SecondAmount,
            "Donation should accumulate"
        );
        
        fundraiser = crowdfunding.getFundraiser(fundraiserId);
        assertEq(
            fundraiser.currentFund, 
            donation1Amount + donation1SecondAmount,
            "Current fund should be 5 ETH"
        );
        
        console.log("Donor1 donated again:", donation1SecondAmount / 1 ether, "ETH");
        console.log("Donor1 total:", donation1.amount / 1 ether, "ETH");
        console.log("Current fund:", fundraiser.currentFund / 1 ether, "ETH");
        
        // ============ STEP 4: Second donor donates ============
        console.log("\n=== STEP 4: Donor2 Donates ===");
        
        uint256 donation2Amount = 4 ether;
        
        vm.startPrank(donor2);
        
        crowdfunding.donate{value: donation2Amount}(fundraiserId);
        
        vm.stopPrank();
        
        fundraiser = crowdfunding.getFundraiser(fundraiserId);
        assertEq(
            fundraiser.currentFund,
            donation1Amount + donation1SecondAmount + donation2Amount,
            "Current fund should be 9 ETH"
        );
        
        console.log("Donor2 donated:", donation2Amount / 1 ether, "ETH");
        console.log("Current fund:", fundraiser.currentFund / 1 ether, "ETH");
        
        // ============ STEP 5: Third donor reaches the goal ============
        console.log("\n=== STEP 5: Donor3 Reaches Goal ===");
        
        uint256 donation3Amount = 2 ether; // This will exceed the goal
        
        vm.startPrank(donor3);
        
        crowdfunding.donate{value: donation3Amount}(fundraiserId);
        
        vm.stopPrank();
        
        fundraiser = crowdfunding.getFundraiser(fundraiserId);
        uint256 totalRaised = donation1Amount + donation1SecondAmount + donation2Amount + donation3Amount;
        
        assertEq(fundraiser.currentFund, totalRaised, "Current fund should be 11 ETH");
        assertTrue(fundraiser.currentFund >= fundraiser.goal, "Goal should be reached");
        
        console.log("Donor3 donated:", donation3Amount / 1 ether, "ETH");
        console.log("Total raised:", fundraiser.currentFund / 1 ether, "ETH");
        console.log("Goal:", fundraiser.goal / 1 ether, "ETH");
        console.log("Goal REACHED!");
        
        // Verify creator can withdraw
        assertTrue(
            crowdfunding.canCreatorWithdraw(fundraiserId),
            "Creator should be able to withdraw"
        );
        
        // ============ STEP 6: Creator withdraws funds ============
        console.log("\n=== STEP 6: Creator Withdraws ===");
        
        uint256 creatorBalanceBefore = creator.balance;
        uint256 contractBalanceBefore = address(crowdfunding).balance;
        
        vm.startPrank(creator);
        
        // Expect FundsWithdrawn event
        vm.expectEmit(true, true, false, true);
        emit FundsWithdrawn(
            creator,
            fundraiserId,
            totalRaised,
            block.timestamp
        );
        
        crowdfunding.withdrawFunds(fundraiserId);
        
        vm.stopPrank();
        
        // Verify withdrawal was successful
        assertEq(
            creator.balance,
            creatorBalanceBefore + totalRaised,
            "Creator should receive all funds"
        );
        
        assertEq(
            address(crowdfunding).balance,
            contractBalanceBefore - totalRaised,
            "Contract balance should decrease"
        );
        
        fundraiser = crowdfunding.getFundraiser(fundraiserId);
        assertEq(fundraiser.currentFund, 0, "Current fund should be 0 after withdrawal");
        assertEq(
            uint256(fundraiser.status),
            uint256(CrowdfundingEther.FundraiserStatus.Successful),
            "Status should be Successful"
        );
        
        console.log("Creator withdrew:", totalRaised / 1 ether, "ETH");
        console.log("Creator new balance:", creator.balance / 1 ether, "ETH");
        console.log("Fundraiser status: Successful");
        
        // ============ STEP 7: Verify donors cannot withdraw ============
        console.log("\n=== STEP 7: Verify Security ===");
        
        assertFalse(
            crowdfunding.canDonorWithdraw(donor1, fundraiserId),
            "Donor1 should NOT be able to withdraw (goal reached)"
        );
        
        assertFalse(
            crowdfunding.canDonorWithdraw(donor2, fundraiserId),
            "Donor2 should NOT be able to withdraw (goal reached)"
        );
        
        assertFalse(
            crowdfunding.canDonorWithdraw(donor3, fundraiserId),
            "Donor3 should NOT be able to withdraw (goal reached)"
        );
        
        console.log("Security check passed: Donors cannot withdraw from successful campaign");
        
        // ============ Final Summary ============
        console.log("\n=== HAPPY PATH TEST COMPLETE ===");
        console.log("Fundraiser created successfully");
        console.log("Multiple donations received (including repeat donor)");
        console.log("Goal reached and exceeded");
        console.log("Creator withdrew funds");
        console.log("Final status: Successful");
        console.log("All security checks passed");
    }
    
    /**
     * @notice Test that creator can withdraw as soon as goal is reached
     * (don't need to wait for deadline)
     */
    function test_HappyPath_EarlyWithdrawal() public {
        console.log("\n=== Testing Early Withdrawal ===");
        
        // Create fundraiser
        vm.prank(creator);
        uint256 fundraiserId = crowdfunding.createFundraiser(GOAL, DEADLINE_DAYS);
        
        // Donate exactly the goal amount
        vm.prank(donor1);
        crowdfunding.donate{value: GOAL}(fundraiserId);
        
        // Verify we're still before the deadline
        CrowdfundingEther.Fundraiser memory fundraiser = crowdfunding.getFundraiser(fundraiserId);
        assertTrue(block.timestamp < fundraiser.deadline, "Should be before deadline");
        
        // Creator should be able to withdraw immediately
        assertTrue(
            crowdfunding.canCreatorWithdraw(fundraiserId),
            "Creator should be able to withdraw before deadline if goal reached"
        );
        
        uint256 creatorBalanceBefore = creator.balance;
        
        vm.prank(creator);
        crowdfunding.withdrawFunds(fundraiserId);
        
        assertEq(
            creator.balance,
            creatorBalanceBefore + GOAL,
            "Creator should receive goal amount"
        );
        
        console.log("Creator can withdraw immediately after goal is reached");
        console.log("No need to wait for deadline");
    }
    
    /**
     * @notice Test exact goal amount scenario
     */
    function test_HappyPath_ExactGoalAmount() public {
        console.log("\n=== Testing Exact Goal Amount ===");
        
        // Create fundraiser
        vm.prank(creator);
        uint256 fundraiserId = crowdfunding.createFundraiser(GOAL, DEADLINE_DAYS);
        
        // Donate EXACTLY the goal (not more, not less)
        vm.prank(donor1);
        crowdfunding.donate{value: GOAL}(fundraiserId);
        
        CrowdfundingEther.Fundraiser memory fundraiser = crowdfunding.getFundraiser(fundraiserId);
        
        assertEq(fundraiser.currentFund, GOAL, "Should have exact goal amount");
        assertTrue(fundraiser.currentFund >= fundraiser.goal, "Goal should be reached");
        
        // Creator should be able to withdraw
        vm.prank(creator);
        crowdfunding.withdrawFunds(fundraiserId);
        
        fundraiser = crowdfunding.getFundraiser(fundraiserId);
        assertEq(
            uint256(fundraiser.status),
            uint256(CrowdfundingEther.FundraiserStatus.Successful),
            "Should be successful"
        );
        
        console.log("Exact goal amount handled correctly");
    }
}