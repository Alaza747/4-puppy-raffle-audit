// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;
pragma experimental ABIEncoderV2;

import {Test, console} from "forge-std/Test.sol";
import {PuppyRaffle} from "../src/PuppyRaffle.sol";
import {PuppyRaffleForTest} from "../src/PuppyRaffleForTest.sol";

contract Audit_PoC_Manipulation is Test {
    PuppyRaffleForTest puppyRaffleForTest;
    uint256 entranceFee = 1e18;
    address playerOne = address(1);
    address playerTwo = address(2);
    address playerThree = address(3);
    address playerFour = address(4);
    address feeAddress = address(99);
    uint256 duration = 1 days;

    function setUp() public {
        puppyRaffleForTest = new PuppyRaffleForTest(
            entranceFee,
            feeAddress,
            duration
        );
    }


    //////////////////////
    /// selectWinner         ///
    /////////////////////
    modifier playersEntered() {
        address[] memory players = new address[](4);
        players[0] = playerOne;
        players[1] = playerTwo;
        players[2] = playerThree;
        players[3] = playerFour;
        puppyRaffleForTest.enterRaffle{value: entranceFee * 4}(players);
        _;
    }

    //////////////////////
    /// EnterRaffle    ///
    /////////////////////

    function testCanManipulatePlayersArray() public playersEntered {
        console.log("Array length before refund: ", puppyRaffleForTest.getArrayLength());
        console.log("Player Address at position 1 of the array: ", puppyRaffleForTest.players(1));
        console.log("Balance before the refund: ", address(puppyRaffleForTest).balance);
        
        vm.prank(playerTwo);
        puppyRaffleForTest.refund(1);
        console.log("Array length after refund: ", puppyRaffleForTest.getArrayLength());
        console.log("Player Address at position 1 of the array: ", puppyRaffleForTest.players(1));
        console.log("Balance after the refund: ", address(puppyRaffleForTest).balance);

        assert(address(puppyRaffleForTest).balance != puppyRaffleForTest.entranceFee() * puppyRaffleForTest.getArrayLength());
    }
}