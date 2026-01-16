// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

contract SwapNFT is IERC721Receiver {
    uint256 internal _nextSwapId;
    struct Swap {
        uint256 tokenIdA;
        uint256 tokenIdB;
        address nftContractA;
        address nftContractB;
        address ownerNftA;
        address ownerNftB;
        bool depositedA;
        bool depositedB;
        uint256 limitTimeOnDays;
    }

    mapping(uint256 => Swap) public swaps;
    mapping(address => uint256[]) public swapsFromUser;

    event SwapCreated(
        uint256 swapId,
        address sender,
        uint256 tokendId,
        address partyB,
        uint256 limitTimeOnDays
    );

    event TokenDeposited(
        address indexed depositer,
        uint256 swapId,
        uint256 tokenId
    );

    error NotTheOwner();
    error NotValidLimitTime();
    error NotValidToken();
    error AlreadyDeposited();
    error InvalidDepositer();
    error OutOfTheTime();
    error NotPossibleToTake();
    error AlreadyWithdrawn();
    error TransactionFailed();
    error InvalidWithdrawer();

    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external pure override returns (bytes4) {
        return this.onERC721Received.selector;
    }

    function createSwap(
        uint256 _tokenIdA,
        address _tokenContractA,
        uint256 _tokenIdB,
        address _tokenContractB,
        uint256 limitTime
    ) public returns (uint256 swapId) {
        if (_tokenContractA == address(0)) revert NotValidToken();
        if (_tokenContractB == address(0)) revert NotValidToken();
        IERC721 tokenA = IERC721(_tokenContractA);
        IERC721 tokenB = IERC721(_tokenContractB);

        if (tokenA.ownerOf(_tokenIdA) != msg.sender) revert NotTheOwner();

        if (limitTime == 0) revert NotValidLimitTime();

        swapId = _nextSwapId++;

        swaps[swapId] = Swap({
            tokenIdA: _tokenIdA,
            tokenIdB: _tokenIdB,
            nftContractA: _tokenContractA,
            nftContractB: _tokenContractB,
            ownerNftA: tokenA.ownerOf(_tokenIdA),
            ownerNftB: tokenB.ownerOf(_tokenIdB),
            depositedA: false,
            depositedB: false,
            limitTimeOnDays: limitTime
        });

        swapsFromUser[msg.sender].push(swapId);

        emit SwapCreated(
            swapId,
            msg.sender,
            _tokenIdA,
            tokenB.ownerOf(_tokenIdB),
            limitTime
        );
    }

    function _transferNFT(
        address depositer,
        uint256 tokenId,
        address tokenContract
    ) internal returns (bool) {
        IERC721 token = IERC721(tokenContract);

        if (depositer != token.ownerOf(tokenId)) revert NotTheOwner();

        token.safeTransferFrom(depositer, address(this), tokenId);

        return true;
    }

    function depositNFT(uint256 swapId) public {
        Swap storage swap = swaps[swapId];

        if (block.timestamp > swap.limitTimeOnDays * 1 days)
            revert OutOfTheTime();

        if (swap.ownerNftA == msg.sender) {
            if (swap.depositedA) revert AlreadyDeposited();

            swap.depositedA = _transferNFT(
                msg.sender,
                swap.tokenIdA,
                swap.nftContractA
            );

            emit TokenDeposited(msg.sender, swapId, swap.tokenIdA);
        } else if (swap.ownerNftB == msg.sender) {
            if (swap.depositedB) revert AlreadyDeposited();

            swap.depositedB = _transferNFT(
                msg.sender,
                swap.tokenIdB,
                swap.nftContractB
            );
            emit TokenDeposited(msg.sender, swapId, swap.tokenIdA);
        } else {
            revert InvalidDepositer();
        }
    }

    function withdrawNFT(address recipient, uint256 tokenId, address tokenContract) public returns(bool) {
        IERC721 token = IERC721(tokenContract);

        if (recipient == token.ownerOf(tokenId)) revert AlreadyWithdrawn();

        token.safeTransferFrom(address(this), recipient, tokenId);

        return true;
    }

    function takeMyNFT(uint256 swapId) public {
        Swap storage swap = swaps[swapId];

        if (!(swap.depositedA && swap.depositedB)) revert NotPossibleToTake();

        if (swap.ownerNftA == msg.sender) {
            bool success = withdrawNFT(msg.sender, swap.tokenIdB, swap.nftContractB);
            if (!success) revert TransactionFailed();
        } else if (swap.ownerNftB == msg.sender) {
            bool success = withdrawNFT(msg.sender, swap.tokenIdA, swap.nftContractA);
            if (!success) revert TransactionFailed();
        } else {
            revert InvalidWithdrawer();
        }
    }
}
