// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "forge-std/Script.sol";
import "../src/SmartAuction.sol";

contract DeploySmartAuction is Script {
    function run() external {
        // Load environment variables for the deployment (replace with real values)
        address nftAddress = vm.envAddress("NFT_ADDRESS");
        uint256 nftId = vm.envUint("NFT_ID");
        address rewardTokenAddress = vm.envAddress("REWARD_TOKEN_ADDRESS");
        uint256 minBidIncrement = vm.envUint("MIN_BID_INCREMENT");

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
