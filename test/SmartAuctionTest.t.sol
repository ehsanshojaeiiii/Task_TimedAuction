// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import "../src/SmartAuction.sol";

contract SmartAuctionTest is Test {
    SmartAuction auction;
    address owner = address(0x123);
    address bidder1 = address(0x456);
    address bidder2 = address(0x789);

    function setUp() public {
        // Deploy the SmartAuction contract with Sepolia VRF configuration
        auction = new SmartAuction(
            0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625, // Sepolia VRF Coordinator
            0x779877A7B0D9E8603169DdbD7836e478b4624789, // LINK Token on Sepolia
            0x6f13400000000000000000000000000000000000, // VRF Wrapper on Sepolia (Example)
            0x2ed0feb3e12a3f7173e2323de4460b8b121618eb7ee839c9d48907f5ea040934, // Key Hash
            12345, // VRF Subscription ID
            200000, // Callback gas limit
            3 // Number of confirmations
        );
    }

    // Test the initial state of the auction contract
    function testInitialState() public {
        assertEq(auction.auctionStarted(), false);
        assertEq(auction.highestBid(), 0);
        assertEq(auction.highestBidder(), address(0));
    }

    // Test to start the auction successfully by the owner
    function testStartAuction() public {
        vm.prank(owner); // Simulate transaction from owner
        auction.startAuction(3600); // Start auction for 1 hour
        assertEq(auction.auctionStarted(), true);
        assertGt(auction.auctionEndTime(), block.timestamp);
    }

    // Test to place bids and ensure the highest bid is correctly updated
    function testPlaceBid() public {
        vm.prank(owner);
        auction.startAuction(3600); // Start auction

        // Bidder1 places a bid
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

    // Test to check that the auction end time extends when a bid is placed within the last 5 minutes
    function testExtendAuctionEndTime() public {
        vm.prank(owner);
        auction.startAuction(3600); // Start auction

        // Fast-forward time to the last 5 minutes
        vm.warp(block.timestamp + 3550);

        // Bidder1 places a bid, extending the auction end time
        vm.prank(bidder1);
        auction.bid{value: 1 ether}();

        // Check that the auction end time was extended by 5 minutes
        uint256 auctionEndTime = auction.auctionEndTime();
        assertGt(auctionEndTime, block.timestamp + 300);
    }

    // Test that a user can withdraw their funds after being outbid
    function testBidderWithdrawFunds() public {
        vm.prank(owner);
        auction.startAuction(3600); // Start auction

        // Bidder1 places a bid
        vm.prank(bidder1);
        auction.bid{value: 1 ether}();

        // Bidder2 places a higher bid
        vm.prank(bidder2);
        auction.bid{value: 1.1 ether}();

        // Bidder1 is outbid and can withdraw funds
        uint256 initialBalance = bidder1.balance;
        vm.prank(bidder1);
        auction.withdraw();

        // Ensure Bidder1 has their funds returned
        assertEq(bidder1.balance, initialBalance + 1 ether);
    }

    // Test ending the auction and finalizing the highest bidder
    function testEndAuction() public {
        vm.prank(owner);
        auction.startAuction(3600); // Start auction

        // Bidder1 places a bid
        vm.prank(bidder1);
        auction.bid{value: 1 ether}();

        // Fast forward to after the auction end time
        vm.warp(block.timestamp + 3601);

        // End the auction
        vm.prank(owner);
        auction.endAuction();

        // Ensure auction is finalized correctly
        assertEq(auction.auctionStarted(), false);
        assertEq(auction.highestBid(), 1 ether);
        assertEq(auction.highestBidder(), bidder1);
    }

    // Test that no bids can be placed after the auction has ended
    function testCannotBidAfterAuctionEnd() public {
        vm.prank(owner);
        auction.startAuction(3600); // Start auction

        // Fast forward to after the auction end time
        vm.warp(block.timestamp + 3601);

        // Attempt to place a bid (should revert)
        vm.prank(bidder1);
        vm.expectRevert("Auction has already ended.");
        auction.bid{value: 1 ether}();
    }

    // Test that only the owner can start the auction
    function testOnlyOwnerCanStartAuction() public {
        // Attempt to start the auction from a non-owner account
        vm.prank(bidder1);
        vm.expectRevert("Ownable: caller is not the owner");
        auction.startAuction(3600);
    }
}
