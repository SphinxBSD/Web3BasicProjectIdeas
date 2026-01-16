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

    error NotTheOwner();
    error NotValidLimitTime();
    error NotValidToken();

    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external pure override returns(bytes4) {
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

        tokenA.safeTransferFrom(msg.sender, address(this), _tokenIdA);

        swaps[swapId].depositedA = true;

        emit SwapCreated(
            swapId,
            msg.sender,
            _tokenIdA,
            tokenB.ownerOf(_tokenIdB),
            limitTime
        );
    }
}
