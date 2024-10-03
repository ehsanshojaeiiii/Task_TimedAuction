// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Script.sol";
import "../src/SmartAuction.sol";

contract DeploySmartAuction is Script {
    function run() external {
        // Hardcoded deployment parameters (replace these with actual values)
        address nftAddress = address(0x1111); // Address of the NFT contract
        uint256 nftId = 1; // NFT ID to auction
        address rewardTokenAddress = address(0x2222); // Address of the ERC20 reward token
        uint256 minBidIncrement = 5; // Minimum bid increment percentage

        // Start broadcasting transactions
        vm.startBroadcast();

        // Deploy the SmartAuction contract
        SmartAuction auction = new SmartAuction(
            nftAddress, // Address of the NFT being auctioned
            nftId, // ID of the NFT token
            rewardTokenAddress, // Address of the ERC20 reward token
            minBidIncrement // Minimum bid increment percentage
        );

        // Output the deployed contract address
        console.log("SmartAuction deployed at:", address(auction));

        // Stop broadcasting transactions
        vm.stopBroadcast();
    }
}
