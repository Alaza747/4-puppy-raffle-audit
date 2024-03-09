// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;
pragma experimental ABIEncoderV2;

import {Test, console} from "forge-std/Test.sol";
import {PuppyRaffle} from "../src/PuppyRaffle.sol";

contract Audit_PoC_Overflow is Test {
    PuppyRaffle puppyRaffle;
    uint256 entranceFee = 28446744073709551615;
    address playerOne = address(1);
    address playerTwo = address(2);
    address playerThree = address(3);
    address playerFour = address(4);
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
        players = new address[](4);
        players[0] = playerOne;
        players[1] = playerTwo;
        players[2] = playerThree;
        players[3] = playerFour;
        puppyRaffle.enterRaffle{value: entranceFee * 4}(players);
        _;
    }

    //////////////////////
    /// Arithmetics    ///
    //////////////////////

    function testArithmetics() public playersEntered{
        console.log("Entrance Fee: ", entranceFee);
        console.log("Number of Players: ", players.length);
        vm.warp(block.timestamp + duration + 1);
        vm.roll(block.number + 1);


        uint256 expectedPayout = ((entranceFee * 4) * 80 / 100);
        uint256 expectedFee = ((entranceFee * 4) * 20 / 100);
        console.log("Expected fee Before: ", expectedFee);
        console.log("Total fee Before: ", puppyRaffle.totalFees());


        puppyRaffle.selectWinner();
        console.log("Real Payout: ", expectedPayout);
        console.log("Real fee After: ", puppyRaffle.totalFees());

        assertEq(puppyRaffle.totalFees(), expectedFee);
    }    
}