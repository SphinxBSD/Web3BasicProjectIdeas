// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

contract SwapNFT is IERC721Receiver {
    uint256 private _nextSwapId;

    enum SwapStatus {
        Active,
        Completed,
        Cancelled
    }

    struct Swap {
        address nftContractA;
        uint256 tokenIdA;
        address partyA;
        address nftContractB;
        uint256 tokenIdB;
        address partyB;
        bool depositedA;
        bool depositedB;
        uint256 expirationTime;
        SwapStatus status;
    }

    mapping(uint256 => Swap) public swaps;

    event SwapCreated(
        uint256 indexed swapId,
        address indexed partyA,
        address nftContractA,
        uint256 tokenIdA,
        address indexed partyB,
        address nftContractB,
        uint256 tokenIdB,
        uint256 expirationTime
    );

    event TokenDeposited(
        uint256 indexed swapId,
        address indexed depositor,
        address nftContract,
        uint256 tokenId
    );

    event SwapCompleted(uint256 indexed swapId);
    
    event SwapCancelled(uint256 indexed swapId);

    event TokenWithdrawn(
        uint256 indexed swapId,
        address indexed withdrawer,
        address nftContract,
        uint256 tokenId
    );

    error InvalidAddress();
    error NotTokenOwner();
    error InvalidDuration();
    error SwapNotActive();
    error NotPartyToSwap();
    error AlreadyDeposited();
    error SwapNotExpired();
    error BothPartiesNotDeposited();
    error SwapExpired();
    error NothingToWithdraw();

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    /**
     * @notice Create a new NFT swap
     * @param _nftContractA Address of the first NFT contract
     * @param _tokenIdA Token ID of the first NFT
     * @param _partyB Address of the counterparty
     * @param _nftContractB Address of the second NFT contract
     * @param _tokenIdB Token ID of the second NFT
     * @param _durationInDays How many days the swap remains valid
     */
    function createSwap(
        address _nftContractA,
        uint256 _tokenIdA,
        address _partyB,
        address _nftContractB,
        uint256 _tokenIdB,
        uint256 _durationInDays
    ) external returns (uint256 swapId) {
        if (_nftContractA == address(0) || _nftContractB == address(0)) {
            revert InvalidAddress();
        }
        if (_partyB == address(0) || _partyB == msg.sender) {
            revert InvalidAddress();
        }
        if (_durationInDays == 0) {
            revert InvalidDuration();
        }

        // Verify msg.sender owns the NFT
        if (IERC721(_nftContractA).ownerOf(_tokenIdA) != msg.sender) {
            revert NotTokenOwner();
        }

        // Verify partyB owns their NFT
        if (IERC721(_nftContractB).ownerOf(_tokenIdB) != _partyB) {
            revert NotTokenOwner();
        }

        swapId = _nextSwapId++;
        uint256 expirationTime = block.timestamp + (_durationInDays * 1 days);

        swaps[swapId] = Swap({
            nftContractA: _nftContractA,
            tokenIdA: _tokenIdA,
            partyA: msg.sender,
            nftContractB: _nftContractB,
            tokenIdB: _tokenIdB,
            partyB: _partyB,
            depositedA: false,
            depositedB: false,
            expirationTime: expirationTime,
            status: SwapStatus.Active
        });

        emit SwapCreated(
            swapId,
            msg.sender,
            _nftContractA,
            _tokenIdA,
            _partyB,
            _nftContractB,
            _tokenIdB,
            expirationTime
        );
    }

    /**
     * @notice Deposit your NFT into the swap
     * @param swapId The ID of the swap
     */
    function depositNFT(uint256 swapId) external {
        Swap storage swap = swaps[swapId];

        if (swap.status != SwapStatus.Active) {
            revert SwapNotActive();
        }
        if (block.timestamp >= swap.expirationTime) {
            revert SwapExpired();
        }

        if (msg.sender == swap.partyA) {
            if (swap.depositedA) {
                revert AlreadyDeposited();
            }

            IERC721(swap.nftContractA).safeTransferFrom(
                msg.sender,
                address(this),
                swap.tokenIdA
            );

            swap.depositedA = true;

            emit TokenDeposited(
                swapId,
                msg.sender,
                swap.nftContractA,
                swap.tokenIdA
            );
        } else if (msg.sender == swap.partyB) {
            if (swap.depositedB) {
                revert AlreadyDeposited();
            }

            IERC721(swap.nftContractB).safeTransferFrom(
                msg.sender,
                address(this),
                swap.tokenIdB
            );

            swap.depositedB = true;

            emit TokenDeposited(
                swapId,
                msg.sender,
                swap.nftContractB,
                swap.tokenIdB
            );
        } else {
            revert NotPartyToSwap();
        }
    }

    /**
     * @notice Execute the swap - transfers NFTs to their new owners
     * @param swapId The ID of the swap
     */
    function executeSwap(uint256 swapId) external {
        Swap storage swap = swaps[swapId];

        if (swap.status != SwapStatus.Active) {
            revert SwapNotActive();
        }
        if (!swap.depositedA || !swap.depositedB) {
            revert BothPartiesNotDeposited();
        }
        if (block.timestamp >= swap.expirationTime) {
            revert SwapExpired();
        }
        if (msg.sender != swap.partyA && msg.sender != swap.partyB) {
            revert NotPartyToSwap();
        }

        // Mark as completed first to prevent reentrancy
        swap.status = SwapStatus.Completed;

        // Transfer NFTs to new owners
        IERC721(swap.nftContractA).safeTransferFrom(
            address(this),
            swap.partyB,
            swap.tokenIdA
        );

        IERC721(swap.nftContractB).safeTransferFrom(
            address(this),
            swap.partyA,
            swap.tokenIdB
        );

        emit SwapCompleted(swapId);
    }

    /**
     * @notice Cancel the swap before both parties deposit
     * @param swapId The ID of the swap
     */
    function cancelSwap(uint256 swapId) external {
        Swap storage swap = swaps[swapId];

        if (swap.status != SwapStatus.Active) {
            revert SwapNotActive();
        }
        if (msg.sender != swap.partyA && msg.sender != swap.partyB) {
            revert NotPartyToSwap();
        }

        // Can only cancel if both haven't deposited yet
        if (swap.depositedA && swap.depositedB) {
            revert BothPartiesNotDeposited();
        }

        swap.status = SwapStatus.Cancelled;

        // Return any deposited NFTs
        if (swap.depositedA) {
            IERC721(swap.nftContractA).safeTransferFrom(
                address(this),
                swap.partyA,
                swap.tokenIdA
            );
        }
        if (swap.depositedB) {
            IERC721(swap.nftContractB).safeTransferFrom(
                address(this),
                swap.partyB,
                swap.tokenIdB
            );
        }

        emit SwapCancelled(swapId);
    }

    /**
     * @notice Withdraw your NFT after expiration if swap didn't complete
     * @param swapId The ID of the swap
     */
    function withdrawAfterExpiration(uint256 swapId) external {
        Swap storage swap = swaps[swapId];

        if (swap.status != SwapStatus.Active) {
            revert SwapNotActive();
        }
        if (block.timestamp < swap.expirationTime) {
            revert SwapNotExpired();
        }

        swap.status = SwapStatus.Cancelled;

        // Return deposited NFTs to original owners
        if (swap.depositedA) {
            IERC721(swap.nftContractA).safeTransferFrom(
                address(this),
                swap.partyA,
                swap.tokenIdA
            );
            emit TokenWithdrawn(
                swapId,
                swap.partyA,
                swap.nftContractA,
                swap.tokenIdA
            );
        }
        if (swap.depositedB) {
            IERC721(swap.nftContractB).safeTransferFrom(
                address(this),
                swap.partyB,
                swap.tokenIdB
            );
            emit TokenWithdrawn(
                swapId,
                swap.partyB,
                swap.nftContractB,
                swap.tokenIdB
            );
        }

        if (!swap.depositedA && !swap.depositedB) {
            revert NothingToWithdraw();
        }

        emit SwapCancelled(swapId);
    }

    /**
     * @notice Get swap details
     * @param swapId The ID of the swap
     */
    function getSwap(uint256 swapId) external view returns (Swap memory) {
        return swaps[swapId];
    }
}