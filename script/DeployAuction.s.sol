// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "forge-std/Script.sol";
import "../src/SmartAuction.sol";

contract DeploySmartAuction is Script {
    function run() external {
        // Load private key and environment variables from .env file
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address vrfCoordinator = vm.envAddress("VRF_COORDINATOR");
        address linkToken = vm.envAddress("LINK_TOKEN");
        address vrfWrapper = vm.envAddress("VRF_WRAPPER");
        bytes32 keyHash = vm.envBytes32("VRF_KEY_HASH");
        uint64 subscriptionId = uint64(vm.envUint("VRF_SUBSCRIPTION_ID"));

        // Start broadcasting the transaction to the network
        vm.startBroadcast(deployerPrivateKey);

        // Deploy the SmartAuction contract
        SmartAuction auction = new SmartAuction(
            vrfCoordinator, // Chainlink VRF Coordinator
            linkToken, // LINK Token Address
            vrfWrapper, // VRF Wrapper Address
            keyHash, // Key Hash for VRF
            subscriptionId, // VRF Subscription ID
            200000, // Callback gas limit
            3 // Number of confirmations
        );

        // Output the deployed contract address to the console
        console.log("SmartAuction deployed at:", address(auction));

        // Stop broadcasting once deployment is complete
        vm.stopBroadcast();
    }
}
