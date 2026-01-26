// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title StakingCloud
 * @notice Corrected version fixing critical bugs in the original implementation
 *
 * FIXES APPLIED:
 * 1. Users can now withdraw their principal after staking period ends
 * 2. Fixed qualification check - must hold for 7 days, not stake 7 days before end
 * 3. Added check for computedQualifiedStaked before allowing claims
 * 4. Reward pool is now properly funded in constructor
 * 5. Fixed division by zero in reward calculation
 * 6. Users can now retrieve both rewards AND principal
 */
contract StakingCloud is Ownable {
    uint256 public constant MIN_STAKE_PERIOD = 7 days;

    struct StakeInfo {
        uint256 amount;
        uint256 stakeTime;
        bool claimed;
        bool withdrawn;
    }

    IERC20 public immutable cloudCoin;
    uint256 public immutable rewardPool;
    bool public computedQualifiedStaked;

    uint256 public totalQualifiedStaked;
    uint256 public beginDate;
    uint256 public endDate;

    mapping(address => StakeInfo) public stakers;
    address[] public stakersList;

    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount);
    event Claimed(address indexed user, uint256 reward);
    event WithdrawnPrincipal(address indexed user, uint256 amount);
    event ComputedQualifiedStaked(uint256 totalQualifiedStaked);

    error InvalidAmount();
    error InsufficientBalance();
    error StakePeriodEnded();
    error AlreadyStaked();
    error InsufficientAllowance();
    error UserHasNotStaked();
    error AlreadyClaimed();
    error AlreadyWithdrawn();
    error StakePeriodNotFinished();
    error StakePeriodNotStarted();
    error NoQualifiedStakers();
    error AlreadyComputed();
    error QualifiedStakersExist();
    error NotComputed();
    error StakePeriodStillActive();
    error RewardPoolNotFunded();

    constructor(
        address _cloudCoin,
        uint256 _rewardPool,
        uint256 _durationInDays
    ) Ownable(msg.sender) {
        cloudCoin = IERC20(_cloudCoin);
        rewardPool = _rewardPool;
        beginDate = block.timestamp;
        endDate = block.timestamp + _durationInDays * 1 days;

        // FIX #4: Ensure reward pool is funded
        // Owner must approve this contract to transfer rewardPool amount before deployment
        bool success = cloudCoin.transferFrom(
            msg.sender,
            address(this),
            _rewardPool
        );
        if (!success) revert RewardPoolNotFunded();
    }

    function stake(uint256 _amount) public {
        if (block.timestamp >= endDate) revert StakePeriodEnded();
        if (block.timestamp < beginDate) revert StakePeriodNotStarted();
        if (_amount <= 0) revert InvalidAmount();
        if (cloudCoin.allowance(msg.sender, address(this)) < _amount)
            revert InsufficientAllowance();

        if (stakers[msg.sender].amount == 0) {
            stakers[msg.sender].amount = _amount;
            stakers[msg.sender].stakeTime = block.timestamp;

            stakersList.push(msg.sender);

            cloudCoin.transferFrom(msg.sender, address(this), _amount);

            emit Staked(msg.sender, _amount);
        } else {
            revert AlreadyStaked();
        }
    }

    // Can only unstake BEFORE staking period ends
    function unstake() public {
        if (block.timestamp >= endDate) revert StakePeriodEnded();
        if (stakers[msg.sender].amount == 0) revert UserHasNotStaked();

        uint256 amount = stakers[msg.sender].amount;
        stakers[msg.sender].amount = 0;
        stakers[msg.sender].stakeTime = 0;

        cloudCoin.transfer(msg.sender, amount);

        emit Unstaked(msg.sender, amount);
    }

    function computeQualifiedStaked() public {
        if (block.timestamp < endDate) revert StakePeriodNotFinished();
        if (computedQualifiedStaked) revert AlreadyComputed();

        for (uint256 i = 0; i < stakersList.length; i++) {
            address staker = stakersList[i];

            // FIX #3: Changed qualification logic
            // Check if user held for at least 7 days AND still has stake at expiration
            if (
                stakers[staker].amount > 0 &&
                endDate >= stakers[staker].stakeTime + MIN_STAKE_PERIOD
            ) {
                totalQualifiedStaked += stakers[staker].amount;
            }
        }
        computedQualifiedStaked = true;
        emit ComputedQualifiedStaked(totalQualifiedStaked);
    }

    function calculateRewards(address _staker) public view returns (uint256) {
        // FIX #5: Handle division by zero
        if (totalQualifiedStaked == 0) return 0;

        // Check if this staker qualifies
        if (
            stakers[_staker].amount == 0 ||
            endDate < stakers[_staker].stakeTime + MIN_STAKE_PERIOD
        ) {
            return 0;
        }

        uint256 userStake = stakers[_staker].amount;
        return (userStake * rewardPool) / totalQualifiedStaked;
    }

    // FIX #3: Added check for computedQualifiedStaked
    function claim() public {
        if (block.timestamp < endDate) revert StakePeriodNotFinished();
        if (!computedQualifiedStaked) revert NotComputed();
        if (stakers[msg.sender].amount == 0) revert UserHasNotStaked();
        if (stakers[msg.sender].claimed) revert AlreadyClaimed();

        uint256 rewards = calculateRewards(msg.sender);
        stakers[msg.sender].claimed = true;

        if (rewards > 0) {
            cloudCoin.transfer(msg.sender, rewards);
            emit Claimed(msg.sender, rewards);
        }
    }

    // FIX #2: NEW FUNCTION - Allow users to withdraw their principal after period ends
    function withdrawPrincipal() public {
        if (block.timestamp < endDate) revert StakePeriodStillActive();
        if (stakers[msg.sender].amount == 0) revert UserHasNotStaked();
        if (stakers[msg.sender].withdrawn) revert AlreadyWithdrawn();

        uint256 amount = stakers[msg.sender].amount;
        stakers[msg.sender].withdrawn = true;

        cloudCoin.transfer(msg.sender, amount);
        emit WithdrawnPrincipal(msg.sender, amount);
    }

    // Combined claim and withdraw for convenience
    function claimAndWithdraw() public {
        claim();
        withdrawPrincipal();
    }

    function withdraw() public onlyOwner {
        if (block.timestamp < endDate) revert StakePeriodNotFinished();
        if (totalQualifiedStaked > 0) revert QualifiedStakersExist();
        if (!computedQualifiedStaked) revert NotComputed();

        uint256 balance = cloudCoin.balanceOf(address(this));
        cloudCoin.transfer(msg.sender, balance);
    }
}
