// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import "../src/SmartAuction.sol";

contract SmartAuctionTest is Test {
    SmartAuction auction;
    address owner = address(0x123); // Set the owner address
    address bidder1 = address(0x456); // Address of first bidder
    address bidder2 = address(0x789); // Address of second bidder
    IERC721 nft;
    IERC20 rewardToken;

    function setUp() public {
        // Mock NFT and reward token setup (using an example address, replace it with actual mocks if needed)
        nft = IERC721(address(0x1111)); // Mock NFT
        rewardToken = IERC20(address(0x2222)); // Mock ERC20 reward token

        // Deploy the auction contract with the correct owner
        vm.prank(owner);
        auction = new SmartAuction(
            address(nft),
            1, // NFT ID
            address(rewardToken),
            5 // Minimum bid increment percentage
        );
    }

    // Test the initial state of the auction contract
    function testInitialState() public view {
        assertEq(auction.auctionStarted(), false);
        assertEq(auction.highestBid(), 0);
        assertEq(auction.highestBidder(), address(0));
    }

    // Test starting the auction (must be called by owner)
    function testStartAuction() public {
        vm.prank(owner); // Simulate the transaction from the owner address
        auction.startAuction(3600); // Start auction for 1 hour
        assertEq(auction.auctionStarted(), true);
        assertGt(auction.auctionEndTime(), block.timestamp);
    }

    // Test placing a bid
    function testPlaceBid() public {
        // Start the auction
        vm.prank(owner); // Ensure the owner starts the auction
        auction.startAuction(3600);

        // Bidder1 places a bid
        vm.prank(bidder1); // Simulate transaction from bidder1
        auction.bid{value: 1 ether}();

        assertEq(auction.highestBid(), 1 ether);
        assertEq(auction.highestBidder(), bidder1);

        // Bidder2 places a higher bid
        vm.prank(bidder2); // Simulate transaction from bidder2
        auction.bid{value: 1.1 ether}(); // Ensure this is greater than 1 ether + minBidIncrement

        assertEq(auction.highestBid(), 1.1 ether);
        assertEq(auction.highestBidder(), bidder2);
    }

    // Test the anti-sniping mechanism: extending the auction end time
    function testAuctionEndTimeExtension() public {
        vm.prank(owner); // Ensure the owner starts the auction
        auction.startAuction(3600); // Start auction for 1 hour

        // Fast forward to the last 5 minutes
        vm.warp(block.timestamp + 3550);

        // Bidder1 places a bid
        vm.prank(bidder1);
        auction.bid{value: 1 ether}();

        // Ensure the auction end time is extended by 5 minutes
        uint256 newEndTime = auction.auctionEndTime();
        assertGt(newEndTime, block.timestamp + 300);
    }

    // Test that only the owner can start the auction
    function testOnlyOwnerCanStartAuction() public {
        // Try to start the auction from a non-owner account (should revert)
        vm.prank(bidder1); // Simulate transaction from non-owner (bidder1)
        vm.expectRevert("Ownable: caller is not the owner");
        auction.startAuction(3600);
    }

    // Test withdrawing funds after being outbid
    function testWithdrawAfterOutbid() public {
        vm.prank(owner); // Start the auction as the owner
        auction.startAuction(3600);

        // Bidder1 places a bid
        vm.prank(bidder1);
        auction.bid{value: 1 ether}();

        // Bidder2 places a higher bid
        vm.prank(bidder2);
        auction.bid{value: 1.1 ether}();

        // Ensure Bidder1 is outbid and can withdraw funds
        uint256 initialBalance = bidder1.balance;
        vm.prank(bidder1);
        auction.withdraw();
        assertEq(bidder1.balance, initialBalance + 1 ether);
    }

    // Test ending the auction (must be called by the owner)
    function testEndAuction() public {
        vm.prank(owner);
        auction.startAuction(3600); // Start auction for 1 hour

        // Bidder1 places a bid
        vm.prank(bidder1);
        auction.bid{value: 1 ether}();

        // Fast forward to after the auction end time
        vm.warp(block.timestamp + 3601);

        // End the auction (only owner can do this)
        vm.prank(owner);
        auction.endAuction();

        // Ensure auction is ended and highest bidder gets the NFT
        assertEq(auction.auctionStarted(), false);
        assertEq(auction.highestBid(), 1 ether);
        assertEq(auction.highestBidder(), bidder1);
    }

    // Test the reward mechanism for the lucky bidder
    function testRewardLuckyBidder() public {
        vm.prank(owner);
        auction.startAuction(3600); // Start auction for 1 hour

        // Bidder1 places a bid
        vm.prank(bidder1);
        auction.bid{value: 1 ether}();

        // Simulate reward mechanism by calling `bid` multiple times
        uint256 initialRewardBalance = rewardToken.balanceOf(bidder1);
        vm.warp(block.timestamp + 1);
        auction.bid{value: 1 ether}();

        // Ensure Bidder1 received a reward (if lucky)
        uint256 newRewardBalance = rewardToken.balanceOf(bidder1);
        assertGt(newRewardBalance, initialRewardBalance);
    }
}
