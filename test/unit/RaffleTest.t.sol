// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import {DeployRaffle} from "script/DeployRaffle.s.sol";
import {HelperConfig, CodeConstant} from "script/HelperConfig.s.sol";
import {Raffle} from "src/Raffle.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

contract RaffleTest is Test, CodeConstant {
    Raffle public raffle;
    HelperConfig public helperConfig;

    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint256 subscriptionId;
    uint32 callbackGasLimit;

    address public player = makeAddr("player");
    uint256 public constant PLAYER_STARTING_BALANCE = 100 ether;
    uint256 public constant SEND_VALUE = 1 ether;

    event RaffleEntered(address indexed player);
    event WinnerPicked(address indexed winner);
    event RequestedRaffleWinner(uint256 indexed requestId);

    modifier upKeepTrue() {
        vm.prank(player);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
    }

    modifier skipFork() {
        if (block.chainid != LOCAL_CHAIN_ID) {
            return;
        }
        _;
    }

    function setUp() external {
        DeployRaffle deployRaffle = new DeployRaffle();
        (raffle, helperConfig) = deployRaffle.deployRaffle();
        //why this why whyyyyyy this pain hhhhhhhhhhhhh
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        entranceFee = config.entranceFee;
        interval = config.interval;
        vrfCoordinator = config.vrfCoordinator;
        gasLane = config.gasLane;
        subscriptionId = config.subscriptionId;
        callbackGasLimit = config.callbackGasLimit;
        vm.deal(player, PLAYER_STARTING_BALANCE);
    }

    function testRaffleInitializesInOpenState() public view {
        // more readable
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
        /**or
         * assert(uint256(raffle.getRaffleState()) == 0);
         */
    }

    /*//////////////////////////////////////////////////////////////
                              ENTER RAFFLE
    //////////////////////////////////////////////////////////////*/

    function testRaffleRevertsWhenYouDontPayEnough() public {
        //Arrange
        vm.prank(player);
        //Act
        vm.expectRevert(Raffle.Raffle__SendMoreToEnterRaffle.selector);
        raffle.enterRaffle();
        //Assret
    }

    function testRaffleRecordPlayersWhenTheyEnter() public {
        vm.prank(player);

        raffle.enterRaffle{value: entranceFee}();

        assertEq(raffle.getPlayers(0), player);
    }

    function testEnteringRaffleEmitsEvents() public {
        vm.prank(player);

        vm.expectEmit(true, false, false, false, address(raffle));
        emit RaffleEntered(player);
        raffle.enterRaffle{value: entranceFee}();
    }

    function testDontAllowPlayersToEnterWhileRaffleIsCalculating()
        public
        upKeepTrue
    {
        //arrange
        raffle.performUpkeep("");
        //Act
        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
        vm.prank(player);
        raffle.enterRaffle{value: entranceFee}();
        //assert
    }

    /*//////////////////////////////////////////////////////////////
                              CHECK UPKEEP
    //////////////////////////////////////////////////////////////*/

    function testCheckUpkeepReturnsFalseIfItHasNoBalance() public {
        // arrange
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        // act
        (bool upKeepNeeded, ) = raffle.checkUpkeep("");
        // assertion
        assert(!upKeepNeeded);
    }

    function testCheckUpkeepReturnsFalseIfRaffleIsNotOpen() public upKeepTrue {
        // arrange
        raffle.performUpkeep("");
        // act
        (bool upKeepNeeded, ) = raffle.checkUpkeep("");
        // assert
        assert(!upKeepNeeded);
    }

    function testCheckUpkeepReturnsFalseIfEnoughTimeHasntPassed() public {
        // arrange
        vm.prank(player);
        raffle.enterRaffle{value: entranceFee}();
        // vm.warp(block.timestamp + 0) == not doing it
        // act
        (bool upKeepNeeded, ) = raffle.checkUpkeep("");
        // assert
        assert(!upKeepNeeded);
    }

    function testCheckUpKeepReturnsTrueWhenParametersAreGood()
        public
        upKeepTrue
    {
        //arrange
        //act
        (bool upKeepNeeded, ) = raffle.checkUpkeep("");
        // assert
        assert(upKeepNeeded);
    }

    /*//////////////////////////////////////////////////////////////
                             PERFORM UPKEEP
    //////////////////////////////////////////////////////////////*/
    function testPerformUpKeepCanOnlyRunIfCheekUpKeepIsTrue()
        public
        upKeepTrue
    {
        // arrange
        // act
        raffle.performUpkeep("");
        // assertion
        // there is a better way with abi.encode later
    }

    function testPerformUpKeepRevertIfCheckUpKeepIsFalse() public {
        vm.prank(player);
        raffle.enterRaffle{value: entranceFee}();
        uint256 currentBalance = address(raffle).balance;
        uint256 playersLength = 1;
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        //act
        vm.expectRevert(
            abi.encodeWithSelector(
                Raffle.Raffle__UpkeepNotNeeded.selector,
                currentBalance,
                raffleState,
                playersLength
            )
        );
        raffle.performUpkeep("");
    }

    function testPerformUpKeepUpdatesRaffleStateAndEmitsRequestId()
        public
        upKeepTrue
    {
        //act
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory enteries = vm.getRecordedLogs();
        bytes32 requestId = enteries[1].topics[1];
        // assert
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        assertEq(uint256(raffleState), 1);
        // if the request was stored in emit it will return value
        assert(uint256(requestId) > 0);
    }

    /*//////////////////////////////////////////////////////////////
                          FULFILL RANDOM WORDS
    //////////////////////////////////////////////////////////////*/

    function testFulfillRandomWordsCanOnlyBeCalledAfterPerformUpKeep(
        uint256 randomRequestId
    ) public upKeepTrue skipFork {
        vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(
            randomRequestId,
            address(raffle)
        );
    }

    function testFulfillRandomWordsPickWinnerResetsAndSendMoneyWithOnePlayer()
        public
        upKeepTrue
        skipFork
    {
        // arrange
        uint256 raffleInitialBalance = address(raffle).balance;
        uint256 playerInitialBalance = player.balance;

        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory emitter = vm.getRecordedLogs();
        bytes32 requestId = emitter[1].topics[1];
        // act
        vm.expectEmit(true, false, false, false, address(raffle));
        emit WinnerPicked(player);
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(
            uint256(requestId),
            address(raffle)
        );

        uint256 raffleFinalBalance = address(raffle).balance;
        uint256 playerFinalBalance = player.balance;

        assert(raffle.getRecentWinner() == player);
        assertEq(uint256(raffle.getRaffleState()), 0);
        vm.expectRevert();
        raffle.getPlayers(0);
        assertEq(raffle.getLastTimeStamp(), block.timestamp);
        assert(raffleFinalBalance == 0);
        assertEq(
            playerInitialBalance + raffleInitialBalance,
            playerFinalBalance
        );
    }

    function testFulfillRandomWordsPickWinnerResetsAndSendMoneyWithMultiplePlayers()
        public
        upKeepTrue
        skipFork
    {
        //arrange
        uint256 numberOfPlayers = 3;
        uint256 startingIndex = 1;

        for (
            uint256 i = startingIndex;
            i < numberOfPlayers + startingIndex;
            i++
        ) {
            address newPlayer = address(uint160(i));
            hoax(newPlayer, PLAYER_STARTING_BALANCE);
            raffle.enterRaffle{value: entranceFee}();
        }
        // uint256 raffleInitialBalance = address(raffle).balance;
        uint256 startingTimeStamp = raffle.getLastTimeStamp();
        uint256 playersInitialBalance = player.balance;

        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];
        // act
        vm.expectEmit(true, false, false, false, address(raffle));
        emit WinnerPicked(address(1)); // doing math winner is address 1
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(
            uint256(requestId),
            address(raffle)
        );
        uint256 endingTimeStamp = raffle.getLastTimeStamp();
        uint256 raffleFinalBalance = address(raffle).balance;
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        uint256 winnerBalance = raffle.getRecentWinner().balance;
        uint256 prize = entranceFee *
            (numberOfPlayers + 1 /* the modifier player*/);

        assertEq(uint256(raffleState), 0);
        vm.expectRevert();
        raffle.getPlayers(0);
        assertEq(raffle.getLastTimeStamp(), block.timestamp);
        assert(raffleFinalBalance == 0);
        assert(endingTimeStamp > startingTimeStamp);
        assert(winnerBalance == prize + playersInitialBalance);
    }
}
