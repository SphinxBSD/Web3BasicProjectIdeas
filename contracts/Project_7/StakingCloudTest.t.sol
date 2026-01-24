// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {StakingCloud} from "./StakingCloud.sol";
import {CloudCoin} from "./CloudCoin.sol";

contract StakingCloudTest is Test {
    StakingCloud public staking;
    CloudCoin public token;
    address public owner;
    address public user1;
    uint256 public rewardPool = 1000 ether;

    function setUp() public {
        owner = address(this);
        user1 = makeAddr("user1");

        token = new CloudCoin(owner);
        staking = new StakingCloud(address(token), rewardPool);

        // Fund Reward Pool
        token.transfer(address(staking), rewardPool);

        // Fund User
        token.transfer(user1, 100 ether);
    }

    function testStakeSuccess() public {
        vm.startPrank(user1);
        token.approve(address(staking), 50 ether);
        staking.stake(50 ether);

        (uint256 amount, , ) = staking.stakers(user1);
        assertEq(amount, 50 ether);
        assertEq(token.balanceOf(address(staking)), rewardPool + 50 ether);
        vm.stopPrank();
    }

    function testStakeRevertInsufficientBalance() public {
        address poorUser = makeAddr("poorUser");
        vm.startPrank(poorUser);
        token.approve(address(staking), 50 ether);

        vm.expectRevert(StakingCloud.InsufficientBalance.selector);
        staking.stake(50 ether);
        vm.stopPrank();
    }

    function testUnstakeSuccess() public {
        vm.startPrank(user1);
        token.approve(address(staking), 50 ether);
        staking.stake(50 ether);

        staking.unstake();
        (uint256 amount, , ) = staking.stakers(user1);
        assertEq(amount, 0);
        assertEq(token.balanceOf(user1), 100 ether); // Original balance
        vm.stopPrank();
    }

    function testClaimSuccess() public {
        vm.startPrank(user1);
        token.approve(address(staking), 100 ether);
        staking.stake(100 ether);
        vm.stopPrank();

        // Warp to end date
        vm.warp(staking.endDate() + 1);

        vm.startPrank(user1);
        staking.claim();

        (, , bool claimed) = staking.stakers(user1);
        assertTrue(claimed);

        // Reward calc: (100 * 1000) / 100 = 1000 rewards
        // Balance = Initial (100) - Staked (100) + Reward (1000) = 1000
        assertEq(token.balanceOf(user1), 1000 ether);
        vm.stopPrank();
    }

    function testClaimRevertTooEarly() public {
        vm.startPrank(user1);
        token.approve(address(staking), 100 ether);
        staking.stake(100 ether);

        vm.expectRevert(StakingCloud.StakePeriodNotFinished.selector);
        staking.claim();
        vm.stopPrank();
    }
}
