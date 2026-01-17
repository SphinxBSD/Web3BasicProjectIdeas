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

    function createFundraiser(
        uint256 _goal,
        uint256 _deadline,
        address _tokenAddr
    ) public returns (uint256 fundraiserId) {
        if (_tokenAddr == address(0)) revert InvalidToken();
        if (_goal == 0) revert InvalidGoal();
        if (_deadline == 0) revert InvalidDeadline();

        fundraiserId = _nextFundaraiserId;
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
        if (fundraiser.status == fundraiserStatus.Finished) revert FundraiserFinished();

        IERC20 token = IERC20(_tokenAddr);
        if (token.allowance(msg.sender, address(this)) < _amount)
            revert NotEnoughAllowance();
        if (token.balanceOf(msg.sender) < _amount) revert NotEnoughBalance();

        if (!hasDonatedToFund[msg.sender][fundraiserId]) {
            uint256 donationId = _nextDonationId++;
            donations[donationId] = Donation({
                amount: _amount,
                withdrawn: false
            });

            donationsIdsFromFund[msg.sender][fundraiserId] = donationId;
            fundraiser.currentFund = _amount;

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

    function withdrawFunds(uint256 _fundaiserId) public {
        Fundraiser storage fundraiser = fundraisers[_fundaiserId];

        if (fundraiser.creator != msg.sender) revert NotTheCreator();
        if (block.timestamp <= fundraiser.deadline) revert FundraiserOngoing();
        if (fundraiser.status == fundraiserStatus.Finished) revert FundraiserFinished();

        IERC20 token = IERC20(fundraiser.tokenAddr);
        // token.transfer(msg.sender, );
    }
}
