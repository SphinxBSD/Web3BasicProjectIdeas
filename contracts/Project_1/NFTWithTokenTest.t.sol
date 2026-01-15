// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {NFTWithToken} from "./NFTWithToken.sol";
import {ERC20Token} from "./ERC20Token.sol";
import {Test} from "forge-std/Test.sol";

contract NFTWithTokenTest is Test {
    NFTWithToken nftWithToken;
    ERC20Token erc20Token;

    address ownerERC20 = makeAddr("ownerERC20");
    address ownerNFT = makeAddr("ownerNFT");
    address client = makeAddr("client");

    function setUp() public {
        erc20Token = new ERC20Token(ownerERC20);
        nftWithToken = new NFTWithToken(ownerNFT, address(erc20Token), 10);
    }

    function test_MintERC20() public {
        vm.startPrank(ownerERC20);
        erc20Token.mint(client, 10);
        vm.stopPrank();

        vm.assertEq(erc20Token.balanceOf(client), 10);
    }

    function test_MintNFT() public {
        vm.startPrank(ownerERC20);
        erc20Token.mint(client, 10);
        vm.stopPrank();

        vm.startPrank(client);
        erc20Token.approve(address(nftWithToken), 10);
        nftWithToken.mint();
        vm.stopPrank();

        vm.assertEq(nftWithToken.balanceOf(client), 1);
    }
}
