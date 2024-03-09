// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;
pragma experimental ABIEncoderV2;

import {Test, console} from "forge-std/Test.sol";
import {PuppyRaffle} from "../src/PuppyRaffle.sol";

contract Audit_PoC_Downcasting is Test {
    PuppyRaffle puppyRaffle;
    uint256 entranceFee = 10e18;
    address playerOne = address(1);
    address playerTwo = address(2);
    address playerThree = address(3);
    address playerFour = address(4);
    address playerFive = address(5);
    address playerSix = address(6);
    address playerSeven = address(7);
    address playerEight = address(8);
    address playerNine = address(9);
    address playerTen = address(10);
    address playerEleven = address(11);
    address playerTwelve = address(12);
    address feeAddress = address(99);
    uint256 duration = 1 days;
    address[] players;

    function setUp() public {
        puppyRaffle = new PuppyRaffle(
            entranceFee,
            feeAddress,
            duration
        );
    }

    modifier playersEntered() {
        players = new address[](12);
        players[0] = playerOne;
        players[1] = playerTwo;
        players[2] = playerThree;
        players[3] = playerFour;
        players[4] = playerFive;
        players[5] = playerSix;
        players[6] = playerSeven;
        players[7] = playerEight;
        players[8] = playerNine;
        players[9] = playerTen;
        players[10] = playerEleven;
        players[11] = playerTwelve;
        puppyRaffle.enterRaffle{value: entranceFee * players.length}(players);
        _;
    }

    //////////////////////
    /// Arithmetics    ///
    //////////////////////

    function testDowncasting() public playersEntered{
        console.log("Entrance Fee: ", entranceFee / 1e18);
        console.log("Number of Players: ", players.length);
        vm.warp(block.timestamp + duration + 1);
        vm.roll(block.number + 1);


        uint256 expectedPayout = ((entranceFee * players.length) * 80 / 100);
        uint256 expectedFee = ((entranceFee * players.length) * 20 / 100);
        console.log("Expected fee Before: ", expectedFee / 1e18);
        console.log("Total fee Before: ", puppyRaffle.totalFees());


        puppyRaffle.selectWinner();
        console.log("Real Winner Payout: ", expectedPayout / 1e18);
        console.log("Real fee After: ", puppyRaffle.totalFees() / 1e18);

        assertEq(puppyRaffle.totalFees(), expectedFee);
    }    
}