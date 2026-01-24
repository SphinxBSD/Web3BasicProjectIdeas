// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract StakingCloud is Ownable {
    struct stakeInfo {
        uint256 amount;
        uint256 lastStakeTime;
        bool claimed;
    }

    IERC20 public immutable cloudCoin;
    uint256 public immutable totalSupply;
    uint256 public totalStaked;
    uint256 public beginDate;
    uint256 public endDate;
    mapping(address => stakeInfo) public stakers;
    mapping(address => bool) public hasStaked;

    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount);
    event Claimed(address indexed user, uint256 amount);

    error AmountMustBeGreaterThanZero();
    error InsufficientBalance();
    error OutOfTime();
    error AlreadyStaked();
    error NotValidStake();
    error InsufficientAllowance();
    error UserHasNotStaked();
    error AlreadyClaimed();
    error StakePeriodNotFinished();
    error NoStakedAmount();

    constructor(address _cloudCoin, uint256 _totalSupply) Ownable(msg.sender) {
        cloudCoin = IERC20(_cloudCoin);
        totalSupply = _totalSupply;
        beginDate = block.timestamp;
        endDate = block.timestamp + 30 days;
    }

    function stake(uint256 _amount) public {
        if (_amount <= 0) revert AmountMustBeGreaterThanZero();
        if (cloudCoin.balanceOf(msg.sender) < _amount)
            revert InsufficientBalance();
        if (block.timestamp >= endDate) revert OutOfTime();
        if (cloudCoin.allowance(msg.sender, address(this)) < _amount)
            revert InsufficientAllowance();
        if (block.timestamp > endDate - 7 days) revert NotValidStake();

        if (hasStaked[msg.sender]) {
            stakers[msg.sender].amount += _amount;
            stakers[msg.sender].lastStakeTime = block.timestamp;
            totalStaked += _amount;

            bool success = cloudCoin.transferFrom(
                msg.sender,
                address(this),
                _amount
            );
            require(success, "Transfer failed");
            emit Staked(msg.sender, _amount);
        } else {
            stakers[msg.sender].amount += _amount;
            stakers[msg.sender].lastStakeTime = block.timestamp;
            totalStaked += _amount;
            hasStaked[msg.sender] = true;

            bool success = cloudCoin.transferFrom(
                msg.sender,
                address(this),
                _amount
            );
            require(success, "Transfer failed");
            emit Staked(msg.sender, _amount);
        }
    }

    function unstake() public {
        if (block.timestamp >= endDate) revert OutOfTime();
        if (!hasStaked[msg.sender]) revert UserHasNotStaked();

        uint256 amount = stakers[msg.sender].amount;
        stakers[msg.sender].amount = 0;
        stakers[msg.sender].lastStakeTime = 0;
        hasStaked[msg.sender] = false;
        totalStaked -= amount;

        bool success = cloudCoin.transfer(msg.sender, amount);
        require(success, "Transfer failed");

        emit Unstaked(msg.sender, amount);
    }

    function calculateRewards(address _staker) public view returns (uint256) {
        if (totalStaked == 0) revert NoStakedAmount();
        uint256 userStake = stakers[_staker].amount;
        return (userStake * totalSupply) / totalStaked;
    }

    function claim() public {
        if (block.timestamp < endDate) revert StakePeriodNotFinished();
        if (!hasStaked[msg.sender]) revert UserHasNotStaked();
        if (stakers[msg.sender].claimed) revert AlreadyClaimed();

        uint256 rewards = calculateRewards(msg.sender);
        stakers[msg.sender].claimed = true;

        bool success = cloudCoin.transfer(msg.sender, rewards);
        require(success, "Transfer failed");

        emit Claimed(msg.sender, rewards);
    }

    function withdraw() public onlyOwner {
        uint256 balance = cloudCoin.balanceOf(address(this));
        bool success = cloudCoin.transfer(msg.sender, balance);
        require(success, "Transfer failed");
    }
}
