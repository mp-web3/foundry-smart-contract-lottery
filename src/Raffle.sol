// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// internal & private view & pure functions
// external & public view & pure functions

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

/**
 * @title A sample Raffle Contract
 * @author Mattia Papa
 * @notice This contract is for creating a sample raffle
 * @dev Implements Chainlink VRFv2
 */

import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

/**
 * @dev VRFConsumerBaseV2 needs to be instantiated by passing it the address of the vrfCoordinator
 */
contract Raffle is VRFConsumerBaseV2 {
    /* Errors */
    // Best practice to name errors is to prefix the error with the name of the contract, then 2 underscores and the error name
    error Raffle__NotEnoughEthSent();
    error Raffle__NotEnoughTimePassed();
    error Raffle__TransferFailed();
    error Raffle__RaffleNotOpen();

    /* Type declarations */
    enum RaffleState {
        OPEN, // 0
        CALCULATING // 1
    }

    /* State variables */
    uint16 private constant REQUEST_CONFIRMATION = 3;
    uint32 private constant NUM_WORDS = 1;

    /* Immutable variables */

    // We are going to be able to set the entrance fee only once, through the constructor when the contract get deployed
    // Thus doing we are saving some gas and we guarantee an equal entrance price
    uint256 private immutable i_entranceFee;

    /**@dev i_interval stores duration of the lottery in seconds */
    uint256 private immutable i_interval;

    /**
     * @dev we need to instantiate a vrfCoordinator using the interface VRFCoordinatorV2Interface, provided by chainlink contracts
     * Address of the vrf Coordinator, is different for each chain
     */
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;

    /**
     * @dev In Chainlink documentation, gasLane corresponds to Key Hash.
     * This is used to specify the gas price for fulfilling requests.
     */
    bytes32 private immutable i_gasLane;

    /**
     * @dev Subscribe to Chainlink VRF in order to get one
     */
    uint64 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;
    uint256 private s_lastTimeStamp;
    address private s_recentWinner;
    RaffleState private s_raffleState;

    // s_players is in storage and not immutable since the address array will grow larger in size
    // It must be payble since we eventually will pay the winner player
    address payable[] private s_players;

    /** Events */
    event EnteredRaffle(address indexed player);
    event PickedWinner(address indexed winner);

    constructor(
        uint256 entranceFee,
        uint256 interval,
        address vrfCoordinator,
        bytes32 gasLane,
        uint64 subscriptionId,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2(vrfCoordinator) {
        i_entranceFee = entranceFee;
        /**@dev i_interval must be in seconds for coherence with block.timestamp */
        i_interval = interval;
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinator);
        i_gasLane = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;

        s_raffleState = RaffleState.OPEN;
        // We want to have a timestamp at contract deployement time (in seconds)
        s_lastTimeStamp = block.timestamp;
    }

    function enterRaffle() external payable {
        // Custom errors were introduced in Solidity ^0.8.4
        // Custom errors are more gas efficient and specific. So instead of:
        // require(msg.value >= i_entranceFee, "Not enough ETH sent!");
        // We are going to declare an error and then revert.

        if (msg.value < i_entranceFee) {
            revert Raffle__NotEnoughEthSent();
        }
        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle__RaffleNotOpen();
        }

        s_players.push(payable(msg.sender));
        // We emitt EnteredRaffle event each time a new player is pushed into s_players array
        emit EnteredRaffle(msg.sender);
    }

    /**
     * @dev This is the function that the Chainlink Automation nodes call
     * to see if it's time to perform an upkeep
     * The following should be true for this to return true: 
     * 1. The time interval has passed between raffle runs
     * 2. The raffle is in the OPEN state 
     * 3. The contract has ETH (aka, players)
     * 4. (Implicit) The subscription is funded with LINK
     * @notice checkUpKeep function will define when the winner is supposed to be picked
     */
    function checkUpKeep(
        bytes memory /* */
    ) public view returns (bool upkeepNeeded, bytes memory /* performData */) {

    }

    // 1. Get a random number
    // 2. Use the random number to pick a player
    // 3. Be automatically called
    function pickWinner() external {
        // Revert if not enough time has passed
        if ((block.timestamp - s_lastTimeStamp) < i_interval) {
            revert Raffle__NotEnoughTimePassed();
        }

        s_raffleState = RaffleState.CALCULATING;
        // Get a random number through Chainlink VRF
        // It requires 2 transactions:
        // 1. Request a random number
        // 2. Get the random number (this is the callback function)

        // Will revert if subscription is not set and funded. (https://docs.chain.link/vrf/v2/subscription/examples/get-a-random-number)
        uint256 requestId = i_vrfCoordinator.requestRandomWords(
            i_gasLane,
            i_subscriptionId,
            REQUEST_CONFIRMATION,
            i_callbackGasLimit,
            NUM_WORDS
        );
    }

    /**
     * @notice Callback function used by VRF Coordinator to return the random number to the contract.
     * @dev Overrides the `fulfillRandomWords` function in the `VRFConsumerBaseV2` contract.
     *      This custom implementation performs additional logic after receiving the random number.
     *      See the original function in `VRFConsumerBaseV2.sol` for more details.
     * @dev When the Chailink Node gets a random number, it will then call the vrfCoordinator
     * @dev The vrfCoordinator will be actually calling the external function `rawFulfillRandomWords` inherited from `VRFConsumerBaseV2.sol`
     * @dev Only at this point `rawFulfillRandomWords` will call our function `fulfillRandomWords`
     * @dev We are overriding the original `fulfillRandomWords` inherited from `VRFConsumerBaseV2`.
     * @param requestId The ID of the VRF request.
     * @param randomWords Array of random words (numbers) returned by VRF Coordinator.
     */
    function fulfillRandomWords(
        uint256 requestId,
        uint256[] memory randomWords
    ) internal override {
        // Checks
        // In this function we don't have checks, but those would include requires, if --> revert, etc...

        // Effects
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        address payable winner = s_players[indexOfWinner];
        s_recentWinner = winner;
        s_raffleState = RaffleState.OPEN;

        s_players = new address payable[](0);
        s_lastTimeStamp = block.timestamp;
        emit PickedWinner(winner);

        // Interactions
        (bool success, ) = winner.call{value: address(this).balance}("");
        if (!success) {
            revert Raffle__TransferFailed();
        }
    }

    /** Getters */

    function getEntranceFee() external view returns (uint256) {
        return i_entranceFee;
    }
}
