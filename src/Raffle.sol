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

contract Raffle {

    /* Errors */
    // Best practice to name errors is to prefix the error with the name of the contract, then 2 underscores and the error name
    error Raffle__NotEnoughEthSent();
    error Raffle__NotEnoughTimePassed();

    /* State variables */
    uint256 private constant REQUEST_CONFIRMATION = 3;

    /* Immutable variables */

    // We are going to be able to set the entrance fee only once, through the constructor when the contract get deployed
    // Thus doing we are saving some gas and we guarantee an equal entrance price
    uint256 private immutable i_entranceFee;

    /**@dev i_interval stores duration of the lottery in seconds */
    uint256 private immutable i_interval;

    uint256 private immutable i_vrfCoordinator;

    // Address of the vrf Coordinator, is different for each chain

    /**
     * @dev In Chainlink documentation, gasLane corresponds to Key Hash.
     * This is used to specify the gas price for fulfilling requests.
     */
    uint256 private immutable i_gasLane;

    /**
    * @dev Subscribe to Chainlink VRF in order to get one
    */
    uint64 private immutable i_subscriptionId;

    uint256 private s_lastTimeStamp;

    // s_players is in storage and not immutable since the address array will grow larger in size
    // It must be payble since we eventually will pay the winner player
    address payable[] private s_players;

    /** Events */
    event EnteredRaffle(address indexed s_players);

    constructor(
        uint256 entranceFee,
        uint256 interval,
        address vrfCoordinator,
        bytes32 gasLane,
        uint64 subscriptionId,
        uint32 callbackGasLimit
    ) {
        i_entranceFee = entranceFee;
        /**@dev i_interval must be in seconds for coherence with block.timestamp */
        i_interval = interval;
        i_vrfCoordinator = vrfCoordinator;
        i_gasLane = gasLane;
        i_subscriptionId = subscriptionId;

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

        s_players.push(payable(msg.sender));
        // We emitt EnteredRaffle event each time a new player is pushed into s_players array
        emit EnteredRaffle(msg.sender);
    }

    // 1. Get a random number
    // 2. Use the random number to pick a player
    // 3. Be automatically called
    function pickWinner() external {
        // Revert if not enough time has passed
        if ((block.timestamp - s_lastTimeStamp) < i_interval) {
            revert Raffle__NotEnoughTimePassed();
        }

        // Get a random number through Chainlink VRF
        // It requires 2 transactions:
        // 1. Request a random number
        // 2. Get the random number (this is the callback function)

        // Will revert if subscription is not set and funded. (https://docs.chain.link/vrf/v2/subscription/examples/get-a-random-number)
        uint256 requestId = i_vrfCoordinator.requestRandomWords(
            i_gasLane,
            i_subscriptionId,
            REQUEST_CONFIRMATION,
            callbackGasLimit,
            numWords
        );
    }

    /** Getters */

    function getEntranceFee() external view returns (uint256) {
        return i_entranceFee;
    }
}
