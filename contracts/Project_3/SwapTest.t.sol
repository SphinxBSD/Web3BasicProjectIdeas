// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";

import {FirstNFT} from "./FirstNFT.sol";
import {SecondNFT} from "./SecondNFT.sol";
import {SwapNFT} from "./SwapNFT.sol";

contract SwapTest is Test {

    FirstNFT firstNFT;
    SecondNFT secondNFT;
    SwapNFT swapNFT;

    address partyA = makeAddr("partyA");
    address partyB = makeAddr("partyB");

    function setUp() public {
        firstNFT = new FirstNFT(address(this));
        secondNFT = new SecondNFT(address(this));
        swapNFT = new SwapNFT();
    }

    function test_CreateSwap() public {
        uint256 tokenIdA = firstNFT.safeMint(partyA);
        uint256 tokenIdB = secondNFT.safeMint(partyB);

        vm.startPrank(partyA);
        firstNFT.approve(address(swapNFT), tokenIdA);
        uint256 swapId_1 = swapNFT.createSwap(
            address(firstNFT),
            tokenIdA,
            partyB,
            address(secondNFT),
            tokenIdB,
            7
        );
        vm.stopPrank();
        assertEq(swapId_1, 0);
    }

    function test_DepositOutOfTime() public {
        uint256 tokenIdA = firstNFT.safeMint(partyA);
        uint256 tokenIdB = secondNFT.safeMint(partyB);

        vm.startPrank(partyA);
        firstNFT.approve(address(swapNFT), tokenIdA);
        uint256 swapId_1 = swapNFT.createSwap(
            address(firstNFT),
            tokenIdA,
            partyB,
            address(secondNFT),
            tokenIdB,
            7
        );
        vm.stopPrank();

        vm.warp(block.timestamp + 8 days);
        
        vm.startPrank(partyA);
        vm.expectRevert();
        swapNFT.depositNFT(swapId_1);
        vm.stopPrank();
    }

    function test_DepositTokenA() public {
        uint256 tokenIdA = firstNFT.safeMint(partyA);
        uint256 tokenIdB = secondNFT.safeMint(partyB);

        vm.startPrank(partyA);
        firstNFT.approve(address(swapNFT), tokenIdA);
        uint256 swapId_1 = swapNFT.createSwap(
            address(firstNFT),
            tokenIdA,
            partyB,
            address(secondNFT),
            tokenIdB,
            7
        );
        vm.stopPrank();

        vm.warp(block.timestamp + 6 days);

        vm.startPrank(partyA);
        swapNFT.depositNFT(swapId_1);
        vm.stopPrank();

        assertEq(address(swapNFT), firstNFT.ownerOf(tokenIdA));
    }

    function test_DepositTokenB() public {
        uint256 tokenIdA = firstNFT.safeMint(partyA);
        uint256 tokenIdB = secondNFT.safeMint(partyB);

        vm.startPrank(partyA);
        firstNFT.approve(address(swapNFT), tokenIdA);
        uint256 swapId_1 = swapNFT.createSwap(
            address(firstNFT),
            tokenIdA,
            partyB,
            address(secondNFT),
            tokenIdB,
            7
        );
        vm.stopPrank();

        vm.startPrank(partyB);
        secondNFT.approve(address(swapNFT), tokenIdB);
        vm.stopPrank();

        vm.warp(block.timestamp + 6 days);

        vm.startPrank(partyB);
        swapNFT.depositNFT(swapId_1);
        vm.stopPrank();

        assertEq(address(swapNFT), secondNFT.ownerOf(tokenIdB));
    }

    function test_WithdrawTokenA() public {
        uint256 tokenIdA = firstNFT.safeMint(partyA);
        uint256 tokenIdB = secondNFT.safeMint(partyB);

        vm.startPrank(partyA);
        firstNFT.approve(address(swapNFT), tokenIdA);
        uint256 swapId_1 = swapNFT.createSwap(
            address(firstNFT),
            tokenIdA,
            partyB,
            address(secondNFT),
            tokenIdB,
            7
        );
        swapNFT.depositNFT(swapId_1);
        vm.stopPrank();

        vm.startPrank(partyB);
        secondNFT.approve(address(swapNFT), tokenIdB);

        vm.warp(block.timestamp + 6 days);

        swapNFT.depositNFT(swapId_1);
        vm.stopPrank();

        vm.startPrank(partyA);
        swapNFT.executeSwap(swapId_1);
        vm.stopPrank();

        assertEq(partyA, secondNFT.ownerOf(tokenIdB));
    }
}