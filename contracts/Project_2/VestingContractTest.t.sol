// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {TokenForVesting} from "./TokenForVesting.sol";
import {VestingContract} from "./VestingContract.sol";

contract VestingContractTest is Test {
    TokenForVesting tokenForVesting;
    VestingContract vestingContract;

    address payer = makeAddr("payer");
    address recipient = makeAddr("recipient");

    function setUp() public {
        tokenForVesting = new TokenForVesting(address(this));
        vestingContract = new VestingContract(address(tokenForVesting), 15);

        tokenForVesting.mint(payer, 100);
    }

    function test_Deposit() public {
        vm.startPrank(payer);
        tokenForVesting.approve(address(vestingContract), 45);
        vestingContract.depositTokens(recipient, 45);
        vm.stopPrank();

        assertEq(tokenForVesting.balanceOf(payer), 55);
    }

    function test_WithdrawToken() public {
        vm.startPrank(payer);
        tokenForVesting.approve(address(vestingContract), 45);
        uint256 vestingId = vestingContract.depositTokens(recipient, 45);
        vm.stopPrank();

        // Test for 3 days
        vm.warp(block.timestamp + 3 days);
        vm.startPrank(recipient);
        vestingContract.withdraw(vestingId);
        vm.stopPrank();

        assertEq(tokenForVesting.balanceOf(recipient), 9);

        // Test for 10 days
        vm.warp(block.timestamp + 7 days);
        vm.startPrank(recipient);
        vestingContract.withdraw(vestingId);
        vm.stopPrank();

        assertEq(tokenForVesting.balanceOf(recipient), 30);
        assertEq(tokenForVesting.balanceOf(address(vestingContract)), 15);
    }
}