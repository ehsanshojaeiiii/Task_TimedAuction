// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract SmartAuction is ReentrancyGuard, Ownable {
    IERC721 public nft;
    IERC20 public rewardToken;
    uint256 public nftId;
    uint256 public auctionEndTime;
    uint256 public highestBid;
    address public highestBidder;
    uint256 public minBidIncrement;
    bool public auctionEnded;
    bool public auctionStarted;
    bool public auctionPaused;
    mapping(address => uint256) public pendingReturns;
    uint256 public rewardChanceCap = 25; // Maximum reward chance in %
    uint256 public biddingExtensionTime = 5 * 60; // 5 minutes extension time for anti-sniping
    uint256 public lastBidTime;

    event AuctionStarted(uint256 endTime);
    event AuctionManuallyStarted(uint256 startTime, uint256 endTime);
    event AuctionPaused();
    event AuctionResumed();
    event BidPlaced(address bidder, uint256 amount);
    event AuctionEnded(address winner, uint256 amount);
    event NFTTransferred(address winner);
    event RewardGranted(address luckyBidder, uint256 amount);
    event AuctionExtended(uint256 newEndTime);

    constructor(
        address _nftAddress,
        uint256 _nftId,
        address _rewardTokenAddress,
        uint256 _minBidIncrement
    ) Ownable(msg.sender) {
        nft = IERC721(_nftAddress);
        rewardToken = IERC20(_rewardTokenAddress);
        nftId = _nftId;
        minBidIncrement = _minBidIncrement;
        auctionStarted = false;
        auctionPaused = false;
    }

    // Admin function to start the auction manually
    function startAuction(uint256 _biddingTime) external onlyOwner {
        require(!auctionStarted, "Auction already started");
        require(!auctionPaused, "Auction is paused, resume to start");
        auctionEndTime = block.timestamp + _biddingTime;
        auctionStarted = true;
        emit AuctionManuallyStarted(block.timestamp, auctionEndTime);
    }

    // Admin function to pause the auction
    function pauseAuction() external onlyOwner {
        require(auctionStarted, "Auction has not started");
        auctionPaused = true;
        emit AuctionPaused();
    }

    // Admin function to resume the auction
    function resumeAuction() external onlyOwner {
        require(auctionPaused, "Auction is not paused");
        auctionPaused = false;
        emit AuctionResumed();
    }

    // Modifier to check if the auction is ongoing
    modifier auctionOngoing() {
        require(auctionStarted, "Auction has not started yet");
        require(!auctionPaused, "Auction is paused");
        require(block.timestamp <= auctionEndTime, "Auction has ended");
        _;
    }

    // Function to place a bid
    function bid() external payable auctionOngoing nonReentrant {
        require(
            msg.value >= highestBid + ((highestBid * minBidIncrement) / 100),
            "Bid too low"
        );

        // Extend auction if bid is placed in the last 5 minutes (anti-sniping)
        if (block.timestamp > auctionEndTime - biddingExtensionTime) {
            auctionEndTime += biddingExtensionTime;
            emit AuctionExtended(auctionEndTime);
        }

        // Refund the previous highest bidder
        if (highestBid != 0) {
            pendingReturns[highestBidder] += highestBid;
        }

        highestBidder = msg.sender;
        highestBid = msg.value;
        lastBidTime = block.timestamp;

        // Basic randomness logic for reward
        rewardLuckyBidder(msg.sender);

        emit BidPlaced(msg.sender, msg.value);
    }

    // Basic pseudo-random reward calculation using block properties
    function rewardLuckyBidder(address bidder) private {
        // Generate pseudo-random number between 1 and 100
        uint256 randomNumber = (uint256(
            keccak256(
                abi.encodePacked(block.timestamp, block.prevrandao, msg.sender)
            )
        ) % 100) + 1;

        if (randomNumber <= rewardChanceCap) {
            uint256 rewardAmount = calculateReward(highestBid);
            rewardToken.transfer(bidder, rewardAmount);
            emit RewardGranted(bidder, rewardAmount);
        }
    }

    // Dynamic reward calculation based on bid size
    function calculateReward(uint256 bidAmount) private pure returns (uint256) {
        uint256 rewardBase = 10 * 10 ** 18; // Base reward of 10 tokens
        return rewardBase + ((bidAmount * rewardBase) / 100); // Example: adjust based on bid size
    }

    // Withdraw funds if outbid
    function withdraw() external nonReentrant {
        uint256 amount = pendingReturns[msg.sender];
        require(amount > 0, "No funds to withdraw");

        pendingReturns[msg.sender] = 0;
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Withdrawal failed");
    }

    // End the auction
    function endAuction() external nonReentrant onlyOwner {
        require(block.timestamp >= auctionEndTime, "Auction is still ongoing");
        require(!auctionEnded, "Auction already ended");

        auctionEnded = true;

        // Transfer NFT to the highest bidder
        nft.transferFrom(address(this), highestBidder, nftId);
        emit NFTTransferred(highestBidder);

        // Transfer the highest bid to the owner
        (bool success, ) = owner().call{value: highestBid}("");
        require(success, "Transfer to owner failed");

        emit AuctionEnded(highestBidder, highestBid);
    }

    // Withdraw NFT if no bids were made
    function withdrawUnsoldNFT() external onlyOwner {
        require(block.timestamp >= auctionEndTime, "Auction is still ongoing");
        require(highestBid == 0, "Cannot withdraw, bids were placed");

        nft.transferFrom(address(this), owner(), nftId);
    }
}
