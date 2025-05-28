// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {Raffle} from "src/Raffle.sol";
import {HelperConfig, CodeConstant} from "./HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "test/mocks/LinkToken.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

contract CreateSubscription is Script {
    // use the default
    function createSubscriptionUsingConfig() public returns (uint256, address) {
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
        address account = helperConfig.getConfig().account;
        (uint256 subId, ) = createSubscription(vrfCoordinator, account);
        return (subId, vrfCoordinator);
    }

    // you can use your own address
    function createSubscription(
        address _vrfCoordinator,
        address _account
    ) public returns (uint256, address) {
        console.log("Creating subscription on chain Id: ", block.chainid);
        vm.startBroadcast(_account);
        uint256 subId = VRFCoordinatorV2_5Mock(_vrfCoordinator)
            .createSubscription();
        vm.stopBroadcast();
        console.log("Your subscription Id is: ", subId);
        console.log(
            "Please update the subscription Id in your HelperConfig.s.sol"
        );
        return (subId, _vrfCoordinator);
    }

    function run() public {
        createSubscriptionUsingConfig();
    }
}

contract FundSubscription is Script, CodeConstant {
    uint256 public constant FUND_AMOUNT = 3 ether; // 3 link because of 18 decimals

    function fundSubscriptionUsingConfig() public {
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
        uint256 subId = helperConfig.getConfig().subscriptionId;
        address linkToken = helperConfig.getConfig().link;
        address account = helperConfig.getConfig().account;
        fundSubscription(vrfCoordinator, subId, linkToken, account);
    }

    function fundSubscription(
        address _vrfCoordinator,
        uint256 _subId,
        address _linkToken,
        address _account
    ) public {
        console.log("Funding subscription: ", _subId);
        console.log("Using vrfCoordinator", _vrfCoordinator);
        console.log("On ChainId: ", block.chainid);
        if (block.chainid == LOCAL_CHAIN_ID) {
            vm.startBroadcast(_account);
            VRFCoordinatorV2_5Mock(_vrfCoordinator).fundSubscription(
                _subId,
                (FUND_AMOUNT * 100000)
            );
            vm.stopBroadcast();
        } else {
            vm.startBroadcast(_account);
            LinkToken(_linkToken).transferAndCall(
                _vrfCoordinator,
                FUND_AMOUNT,
                abi.encode(_subId)
            );
        }
    }

    function run() public {
        fundSubscriptionUsingConfig();
    }
}

contract CreateConsumer is Script {
    function createConsumerUsingConfig(address _mostRecentlyDeployed) public {
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
        uint256 subId = helperConfig.getConfig().subscriptionId;
        address account = helperConfig.getConfig().account;
        createConsumer(vrfCoordinator, subId, _mostRecentlyDeployed, account);
    }

    function createConsumer(
        address _vrfCoordinator,
        uint256 _subId,
        address _ContractToBeConsumer,
        address _account
    ) public {
        console.log("Adding consumer: ", _ContractToBeConsumer);
        console.log("to VRF coordinator: ", _vrfCoordinator);
        console.log("On ChainId: ", block.chainid);
        vm.startBroadcast(_account);
        VRFCoordinatorV2_5Mock(_vrfCoordinator).addConsumer(
            _subId,
            _ContractToBeConsumer
        );
        vm.stopBroadcast();
    }

    function run() public {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment(
            "Raffle",
            block.chainid
        );
        createConsumerUsingConfig(mostRecentlyDeployed);
    }
}
