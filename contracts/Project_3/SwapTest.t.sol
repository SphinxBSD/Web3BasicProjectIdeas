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
            tokenIdA,
            address(firstNFT),
            tokenIdB,
            address(secondNFT),
            7
        );
        vm.stopPrank();
        assertEq(firstNFT.balanceOf(address(swapNFT)), 1);
        assertEq(swapId_1, 0);
    }


}