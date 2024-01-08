// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

/**
 * @title A sample Raffle Contract
 * @author Mattia Papa
 * @notice This contract is for creating a sample raffle
 * @dev Implements Chainlink VRFv2
 */

contract Raffle {
    // We are going to be able to set the entrance fee only once, through the constructor when the contract get deployed
    // Thus doing we are saving some gas and we guarantee an equal entrance price
    uint256 private immutable i_entranceFee;

    constructor(uint256 entranceFee) {
        i_entranceFee = entranceFee;
    }

    function enterRaffle() public payable {

    }

    function pickWinner() public { 

    }



    /* GETTER FUNCTIONS */
    
    function getEntranceFee() external view returns (uint256) {
        return i_entranceFee;
    }
}