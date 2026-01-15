// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract VestingContract {
    IERC20 public immutable paymentToken;
    uint256 public immutable vestingDurationDays;

    uint256 private _nextVestingId;

    struct VestingSchedule {
        address payer;
        address recipient;
        uint256 totalAmount;
        uint256 startTime;
        uint256 releasedAmount;
        bool revoked;
    }
    mapping(uint256 => VestingSchedule) public vestingSchedules;

    mapping(address => uint256[]) public recipientVestings;

    event VestingCreated(
        uint256 indexed vestingId,
        address indexed payer,
        address indexed recipient,
        uint256 amount,
        uint256 startTime
    );

    event TokensReleased(
        uint256 indexed vestingId,
        address indexed recipient,
        uint256 amount
    );

    event VestingRevoked(uint256 indexed vestingId, uint256 refundedAmount);

    error InsufficientBalance();
    error InsufficientAllowance();
    error InvalidRecipient();
    error InvalidAmount();
    error NoTokensAvailable();
    error NotAuthorized();
    error ErrorVestingRevoked();
    error TransferFailed();

    constructor(address _token, uint256 _vestingDurationDays) {
        require(_token != address(0), "Invalid token address");
        require(_vestingDurationDays > 0, "Duration must be positive");

        vestingDurationDays = _vestingDurationDays;
        paymentToken = IERC20(_token);
    }

    /**
     * @notice Create a vesting schedule for a recipient
     * @param recipient Address that will receive the vested tokens
     * @param amount Total amount of tokens to vest
     * @return vestingId Unique identifier for this vesting schedule
     */
    function depositTokens(
        address recipient,
        uint256 amount
    ) public returns (uint256 vestingId) {
        if (recipient == address(0)) revert InvalidRecipient();
        if (amount == 0) revert InvalidAmount();

        if (paymentToken.balanceOf(msg.sender) < amount)
            revert InsufficientBalance();
        if (paymentToken.allowance(msg.sender, address(this)) < amount)
            revert InsufficientAllowance();

        bool success = paymentToken.transferFrom(
            msg.sender,
            address(this),
            amount
        );
        if (!success) revert TransferFailed();

        vestingId = _nextVestingId;
        vestingSchedules[_nextVestingId] = VestingSchedule({
            payer: msg.sender,
            recipient: recipient,
            totalAmount: amount,
            startTime: block.timestamp,
            releasedAmount: 0,
            revoked: false
        });

        recipientVestings[msg.sender].push(vestingId);

        emit VestingCreated(
            vestingId,
            msg.sender,
            recipient,
            amount,
            block.timestamp
        );
    }

    /**
     * @notice Calculate how many tokens are currently vested and available
     * @param vestingId The vesting schedule ID
     * @return The amount of tokens that can be withdrawn
     */
    function getReleasableAmount(
        uint256 vestingId
    ) public view returns (uint256) {
        VestingSchedule memory schedule = vestingSchedules[vestingId];

        if (schedule.revoked || schedule.totalAmount == 0) {
            return 0;
        }

        uint256 elapsedTime = block.timestamp - schedule.startTime;
        uint256 vestingDuration = vestingDurationDays * 1 days;

        uint256 vestedAmount;
        if (elapsedTime >= vestingDuration) {
            vestedAmount = schedule.totalAmount;
        } else {
            vestedAmount =
                (schedule.totalAmount * elapsedTime) /
                vestingDuration;
        }
        return vestedAmount - schedule.releasedAmount;
    }

    /**
     * @notice Withdraw vested tokens for a specific vesting schedule
     * @param vestingId The vesting schedule ID to withdraw from
     */
    function withdraw(uint256 vestingId) external {
        VestingSchedule storage schedule = vestingSchedules[vestingId];

        if (schedule.recipient != msg.sender) revert NotAuthorized();

        if (schedule.revoked) revert ErrorVestingRevoked();

        uint256 releasableAmount = getReleasableAmount(vestingId);

        if (releasableAmount == 0) {
            revert NoTokensAvailable();
        }

        schedule.releasedAmount += releasableAmount;

        bool success = paymentToken.transfer(msg.sender, releasableAmount);
        if (!success) revert TransferFailed();

        emit TokensReleased(vestingId, msg.sender, releasableAmount);
    }

    /**
     * @notice Withdraw from all vesting schedules for the caller
     */
    function withdrawAll() external {
        uint256[] memory vestingIds = recipientVestings[msg.sender];
        uint256 totalReleasable = 0;

        for (uint256 i = 0; i < vestingIds.length; i++) {
            uint256 vestingId = vestingIds[i];
            VestingSchedule storage schedule = vestingSchedules[vestingId];

            if (schedule.revoked) continue;

            uint256 releasableAmount = getReleasableAmount(vestingId);
            if (releasableAmount > 0) {
                schedule.releasedAmount += releasableAmount;
                totalReleasable += releasableAmount;

                emit TokensReleased(vestingId, msg.sender, releasableAmount);
            }
        }

        if (totalReleasable == 0) revert NoTokensAvailable();

        bool success = paymentToken.transfer(msg.sender, totalReleasable);
        if (!success) revert TransferFailed();
    }

    /**
     * @notice Get all vesting IDs for a recipient
     */
    function getRecipientVestings(
        address recipient
    ) external view returns (uint256[] memory) {
        return recipientVestings[recipient];
    }

    /**
     * @notice Get detailed information about a vesting schedule
     */
    function getVestingInfo(
        uint256 vestingId
    )
        external
        view
        returns (
            address payer,
            address recipient,
            uint256 totalAmount,
            uint256 releasedAmount,
            uint256 releasableAmount,
            uint256 startTime,
            bool revoked
        )
    {
        VestingSchedule memory schedule = vestingSchedules[vestingId];
        return (
            schedule.payer,
            schedule.recipient,
            schedule.totalAmount,
            schedule.releasedAmount,
            getReleasableAmount(vestingId),
            schedule.startTime,
            schedule.revoked
        );
    }
}
