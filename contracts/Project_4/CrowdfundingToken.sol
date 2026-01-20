// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract CrowdfundingToken {
    // Create a Fundraiser struct: creator, goal, deadline, tokenAddress, fundraiseStatus
    // Create a "createFundraiser()" function with goal and a deadline as arguments
    // Write a "donate()" function with a fundraiserId as parameter
    // Map the donations address => Fundraiser
    // Write a "withdraw()" function which has to have the following features:
    // - Should be called only by the creator of the fundraising
    // - Should validate the deadline has not been passed

    uint256 internal _nextFundaraiserId;
    uint256 internal _nextDonationId;

    enum fundraiserStatus {
        Ongoing,
        Finished,
        Cancelled
    }

    struct Fundraiser {
        address creator;
        uint256 goal;
        uint256 currentFund;
        uint256 deadline;
        address tokenAddr;
        fundraiserStatus status;
    }

    struct Donation {
        address tokenAddr;
        uint256 amount;
        bool withdrawn;
    }

    mapping(uint256 => Fundraiser) public fundraisers;
    mapping(address => mapping(uint256 => bool)) hasDonatedToFund;
    mapping(address => mapping(uint256 => uint256)) donationsIdsFromFund;
    mapping(uint256 => Donation) public donations;

    event FundraiserCreated(
        uint256 indexed fundraiserId,
        address indexed creator,
        uint256 goal,
        uint256 deadline
    );

    event DonatedToFundraiser(
        address indexed donator,
        uint256 indexed fundraiserId,
        uint256 indexed donationId,
        uint256 amount,
        address tokenAddr
    );

    event FundsWithdrawn(
        address indexed sender,
        uint256 indexed fundaiserId,
        uint256 totalFunds
    );

    event DonationWithdrawn(
        address indexed sender,
        uint256 indexed fundraiserId,
        uint256 indexed donationId,
        uint256 amount
    );

    event FundraiserCancelled(
        uint256 indexed fundraiserId,
        address indexed creator
    );

    error InvalidToken();
    error InvalidGoal();
    error InvalidDeadline();
    error DifferentToken();
    error OutOfTheTime();
    error NotEnoughAllowance();
    error NotEnoughBalance();
    error TransactionFailed();
    error NotTheCreator();
    error FundraiserOngoing();
    error FundraiserFinished();
    error GoalNotReached();
    error HasNotDonated();
    error AlreadyWithdrawn();
    error FundraiserLocked();
    error GoalReached();

    function createFundraiser(
        uint256 _goal,
        uint256 _deadline,
        address _tokenAddr
    ) public returns (uint256 fundraiserId) {
        if (_tokenAddr == address(0)) revert InvalidToken();
        if (_goal == 0) revert InvalidGoal();
        if (_deadline == 0) revert InvalidDeadline();

        fundraiserId = _nextFundaraiserId++;
        fundraisers[fundraiserId] = Fundraiser({
            creator: msg.sender,
            goal: _goal,
            currentFund: 0,
            deadline: block.timestamp + (_deadline * 1 days),
            tokenAddr: _tokenAddr,
            status: fundraiserStatus.Ongoing
        });

        emit FundraiserCreated(
            fundraiserId,
            msg.sender,
            _goal,
            block.timestamp + (_deadline * 1 days)
        );
    }

    function donate(
        uint256 fundraiserId,
        address _tokenAddr,
        uint256 _amount
    ) public {
        Fundraiser storage fundraiser = fundraisers[fundraiserId];

        if (fundraiser.tokenAddr != _tokenAddr) revert DifferentToken();
        if (block.timestamp > fundraiser.deadline) revert OutOfTheTime();
        if (fundraiser.status == fundraiserStatus.Finished)
            revert FundraiserFinished();

        IERC20 token = IERC20(_tokenAddr);
        if (token.allowance(msg.sender, address(this)) < _amount)
            revert NotEnoughAllowance();
        if (token.balanceOf(msg.sender) < _amount) revert NotEnoughBalance();

        if (!hasDonatedToFund[msg.sender][fundraiserId]) {
            uint256 donationId = _nextDonationId++;
            donations[donationId] = Donation({
                tokenAddr: _tokenAddr,
                amount: _amount,
                withdrawn: false
            });

            donationsIdsFromFund[msg.sender][fundraiserId] = donationId;
            fundraiser.currentFund += _amount;
            hasDonatedToFund[msg.sender][fundraiserId] = true;

            bool success = token.transferFrom(
                msg.sender,
                address(this),
                _amount
            );
            if (!success) revert TransactionFailed();

            emit DonatedToFundraiser(
                msg.sender,
                fundraiserId,
                donationId,
                _amount,
                _tokenAddr
            );
        } else {
            uint256 donationId = donationsIdsFromFund[msg.sender][fundraiserId];
            Donation storage donation = donations[donationId];
            donation.amount += _amount;
            donation.withdrawn = false;

            fundraiser.currentFund += _amount;

            bool success = token.transferFrom(
                msg.sender,
                address(this),
                _amount
            );
            if (!success) revert TransactionFailed();

            emit DonatedToFundraiser(
                msg.sender,
                fundraiserId,
                donationId,
                _amount,
                _tokenAddr
            );
        }
    }

    function withdrawFunds(uint256 _fundraiserId) public {
        Fundraiser storage fundraiser = fundraisers[_fundraiserId];

        if (fundraiser.creator != msg.sender) revert NotTheCreator();

        if (fundraiser.status != fundraiserStatus.Ongoing)
            revert FundraiserFinished();
        if (fundraiser.currentFund < fundraiser.goal) revert GoalNotReached();

        uint256 amountToSend = fundraiser.currentFund;
        fundraiser.status = fundraiserStatus.Finished;
        fundraiser.currentFund = 0;

        IERC20 token = IERC20(fundraiser.tokenAddr);
        bool success = token.transfer(msg.sender, amountToSend);
        if (!success) revert TransactionFailed();

        emit FundsWithdrawn(msg.sender, _fundraiserId, amountToSend);
    }

    function withdrawDonation(uint256 _fundraiserId) public {
        if (!hasDonatedToFund[msg.sender][_fundraiserId])
            revert HasNotDonated();

        Fundraiser storage fundraiser = fundraisers[_fundraiserId];
        uint256 donationId = donationsIdsFromFund[msg.sender][_fundraiserId];

        Donation storage donation = donations[donationId];
        if (donation.withdrawn) revert AlreadyWithdrawn();
        if (block.timestamp <= fundraiser.deadline) revert FundraiserOngoing();
        if (fundraiser.currentFund >= fundraiser.goal) revert GoalReached();
        if (fundraiser.status == fundraiserStatus.Finished)
            revert FundraiserFinished();

        uint256 amountDonated = donation.amount;
        donation.withdrawn = true;
        donation.amount = 0;

        fundraiser.currentFund -= amountDonated;

        IERC20 token = IERC20(donation.tokenAddr);
        bool success = token.transfer(msg.sender, amountDonated);
        if (!success) revert TransactionFailed();

        emit DonationWithdrawn(
            msg.sender,
            _fundraiserId,
            donationId,
            amountDonated
        );
    }

    function cancelCrowdfunding(uint256 _fundraiserId) public {
        Fundraiser storage fundraiser = fundraisers[_fundraiserId];

        if (msg.sender != fundraiser.creator) revert NotTheCreator();
        if (fundraiser.status != fundraiserStatus.Ongoing)
            revert FundraiserFinished();
        if (fundraiser.currentFund >= fundraiser.goal) revert GoalReached();

        fundraiser.status = fundraiserStatus.Cancelled;

        emit FundraiserCancelled(_fundraiserId, msg.sender);
    }
}
