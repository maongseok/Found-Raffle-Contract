// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title A sample Raffle Script contract
 * @author MDS
 * @notice this contract for deploying RaffleContract
 * @dev Deployment envirement
 */
import {Script} from "forge-std/Script.sol";
import {Raffle} from "src/Raffle.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {CreateSubscription, FundSubscription, CreateConsumer} from "./Interactions.s.sol";

contract DeployRaffle is Script {
    function deployRaffle() public returns (Raffle, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        if (config.subscriptionId == 0) {
            // create subscription
            CreateSubscription createSubscription = new CreateSubscription();
            // about the config.vrfCoordinator why we didn't just ignore it since we already have it
            (config.subscriptionId, config.vrfCoordinator) = createSubscription
                .createSubscription(config.vrfCoordinator, config.account);
            // fund it
            FundSubscription fundSubscription = new FundSubscription();
            fundSubscription.fundSubscription(
                config.vrfCoordinator,
                config.subscriptionId,
                config.link,
                config.account
            );
        }
        vm.startBroadcast(config.account);
        Raffle raffle = new Raffle(
            config.entranceFee,
            config.interval,
            config.vrfCoordinator,
            config.gasLane,
            config.subscriptionId,
            config.callbackGasLimit
        );
        vm.stopBroadcast();
        // we already have broadcast in the createConsumer function
        CreateConsumer createConsumer = new CreateConsumer();
        createConsumer.createConsumer(
            config.vrfCoordinator,
            config.subscriptionId,
            address(raffle),
            config.account
        );
        return (raffle, helperConfig);
    }

    function run() external returns (Raffle, HelperConfig) {
        return deployRaffle();
    }
}
