// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/VRFV2WrapperConsumerBase.sol";

contract SmartAuction is VRFV2WrapperConsumerBase, ReentrancyGuard, Ownable {
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

    // Chainlink VRF V2 variables
    uint64 public subscriptionId;
    bytes32 public keyHash;
    uint32 public callbackGasLimit;
    uint16 public requestConfirmations;
    uint32 public numWords = 1; // We need only 1 random number
    mapping(uint256 => address) public requestIdToBidder;

    event AuctionStarted(uint256 endTime);
    event AuctionManuallyStarted(uint256 startTime, uint256 endTime);
    event AuctionPaused();
    event AuctionResumed();
    event BidPlaced(address bidder, uint256 amount);
    event AuctionEnded(address winner, uint256 amount);
    event NFTTransferred(address winner);
    event RewardGranted(address luckyBidder, uint256 amount);
    event AuctionExtended(uint256 newEndTime);
    event RandomnessRequested(uint256 requestId, address bidder);

    constructor(
        address _nftAddress,
        uint256 _nftId,
        address _rewardTokenAddress,
        uint256 _minBidIncrement,
        address _vrfCoordinator,
        address _linkToken,
        address _wrapperAddress,
        bytes32 _keyHash,
        uint64 _subscriptionId,
        uint32 _callbackGasLimit,
        uint16 _requestConfirmations
    ) VRFV2WrapperConsumerBase(_linkToken, _wrapperAddress) {
        nft = IERC721(_nftAddress);
        rewardToken = IERC20(_rewardTokenAddress);
        nftId = _nftId;
        minBidIncrement = _minBidIncrement;
        keyHash = _keyHash;
        subscriptionId = _subscriptionId;
        callbackGasLimit = _callbackGasLimit;
        requestConfirmations = _requestConfirmations;
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

        // Request randomness for lucky bidder reward
        requestRandomnessForReward(msg.sender);

        emit BidPlaced(msg.sender, msg.value);
    }

    // Dynamic reward calculation based on bid size
    function calculateReward(uint256 bidAmount) private view returns (uint256) {
        uint256 rewardBase = 10 * 10 ** 18; // Base reward of 10 tokens
        return rewardBase + ((bidAmount * rewardBase) / 100); // Example: adjust based on bid size
    }

    // Request randomness from Chainlink VRF V2
    function requestRandomnessForReward(address bidder) internal {
        uint256 requestId = requestRandomWords(
            keyHash,
            subscriptionId,
            requestConfirmations,
            callbackGasLimit,
            numWords
        );
        requestIdToBidder[requestId] = bidder;
        emit RandomnessRequested(requestId, bidder);
    }

    // Function that Chainlink VRF V2 calls to fulfill the randomness request
    function fulfillRandomWords(
        uint256 requestId,
        uint256[] memory randomWords
    ) internal override {
        address bidder = requestIdToBidder[requestId];
        uint256 randomness = randomWords[0]; // Use the first random word
        uint256 rewardChance = (randomness % 100) + 1; // Generate a number between 1-100
        if (rewardChance <= rewardChanceCap) {
            uint256 rewardAmount = calculateReward(highestBid); // Reward now based on bid size
            rewardToken.transfer(bidder, rewardAmount);
            emit RewardGranted(bidder, rewardAmount);
        }
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
