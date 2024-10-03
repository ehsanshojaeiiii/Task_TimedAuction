// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "forge-std/Test.sol";
import "../src/SmartAuction.sol";

contract SmartAuctionTest is Test {
    SmartAuction auction;
    address owner = address(0x123);
    address bidder1 = address(0x456);
    address bidder2 = address(0x789);

    function setUp() public {
        // Deploy the SmartAuction contract
        auction = new SmartAuction(
            0x2ed4a24F60e826a9d56e180be5420e5cc8F6cBA7, // VRF Coordinator
            0x326C977E6efc84E512bB9C30f76E30c160eD06FB, // LINK Token
            0x0814A00a7Ef48b2Ec2A022fcBA02b4BfF12044f8, // VRF Wrapper
            0xcc294a528480a989fbc9cdd5b6bb267eb7d64540e43d04c9e914ede62f158735, // Key Hash
            12345, // Subscription ID
            200000, // Callback gas limit
            3 // Number of confirmations
        );
    }

    // Test to ensure the initial state of the auction contract is correct
    function testInitialState() public {
        assertEq(auction.auctionStarted(), false);
        assertEq(auction.highestBid(), 0);
        assertEq(auction.highestBidder(), address(0));
    }

    // Test to start the auction successfully by the owner
    function testStartAuction() public {
        vm.prank(owner);
        auction.startAuction(3600); // Start auction for 1 hour
        assertEq(auction.auctionStarted(), true);
        assertGt(auction.auctionEndTime(), block.timestamp);
    }

    // Test to ensure bids are placed and highest bid is updated
    function testPlaceBid() public {
        // Start the auction
        vm.prank(owner);
        auction.startAuction(3600);

        // Bidder1 places bid
        vm.prank(bidder1);
        auction.bid{value: 1 ether}();

        assertEq(auction.highestBid(), 1 ether);
        assertEq(auction.highestBidder(), bidder1);

        // Bidder2 places a higher bid
        vm.prank(bidder2);
        auction.bid{value: 1.1 ether}();

        assertEq(auction.highestBid(), 1.1 ether);
        assertEq(auction.highestBidder(), bidder2);
    }

    // Test to extend the auction end time if a bid is placed in the last 5 minutes
    function testExtendAuctionEndTime() public {
        vm.prank(owner);
        auction.startAuction(3600); // Start auction for 1 hour

        // Simulate the time passing to the last 5 minutes of the auction
        vm.warp(block.timestamp + 3550);

        // Bidder1 places a bid, triggering an auction extension
        vm.prank(bidder1);
        auction.bid{value: 1 ether}();

        // Check that the auction end time was extended by 5 minutes
        uint256 auctionEndTime = auction.auctionEndTime();
        assertGt(auctionEndTime, block.timestamp + 300);
    }

    // Test that an outbid user can withdraw their funds
    function testBidderWithdrawsFunds() public {
        vm.prank(owner);
        auction.startAuction(3600); // Start auction

        // Bidder1 places a bid
        vm.prank(bidder1);
        auction.bid{value: 1 ether}();

        // Bidder2 places a higher bid
        vm.prank(bidder2);
        auction.bid{value: 1.1 ether}();

        // Bidder1 is now outbid and should be able to withdraw their funds
        uint256 initialBalance = bidder1.balance;
        vm.prank(bidder1);
        auction.withdraw();

        // Ensure Bidder1 has their funds returned
        assertEq(bidder1.balance, initialBalance + 1 ether);
    }

    // Test ending the auction and finalizing the highest bid
    function testEndAuction() public {
        vm.prank(owner);
        auction.startAuction(3600); // Start auction

        // Bidder1 places a bid
        vm.prank(bidder1);
        auction.bid{value: 1 ether}();

        // Fast forward time to after the auction end time
        vm.warp(block.timestamp + 3601);

        // End the auction
        vm.prank(owner);
        auction.endAuction();

        // Ensure the auction is finalized and highest bidder is correct
        assertEq(auction.auctionStarted(), false);
        assertEq(auction.highestBid(), 1 ether);
        assertEq(auction.highestBidder(), bidder1);
    }

    // Test to ensure users can't bid after the auction has ended
    function testCannotBidAfterAuctionEnd() public {
        vm.prank(owner);
        auction.startAuction(3600); // Start auction

        // Fast forward time to after the auction end time
        vm.warp(block.timestamp + 3601);

        // Try placing a bid after the auction has ended (should revert)
        vm.prank(bidder1);
        vm.expectRevert("Auction has already ended.");
        auction.bid{value: 1 ether}();
    }

    // Test that only the owner can start the auction
    function testOnlyOwnerCanStartAuction() public {
        // Try to start the auction from a non-owner address (should revert)
        vm.prank(bidder1);
        vm.expectRevert("Ownable: caller is not the owner");
        auction.startAuction(3600);
    }
}
