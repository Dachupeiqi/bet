// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";

import "./interfaces/IBetPlatform.sol";
import "./lib/NoDelegateCall.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import {SafeTransferLib} from "solmate/src/utils/SafeTransferLib.sol";

import {BetFundPool} from "./BetFundPool.sol";

import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

// Uncomment this line to use console.log
import "hardhat/console.sol";

contract BetPlatform is IBetPlatform, NoDelegateCall, Ownable, ReentrancyGuard {
    using SafeMath for uint256;

    using EnumerableSet for EnumerableSet.UintSet;

    using EnumerableSet for EnumerableSet.AddressSet;

    uint256 private betId;

    EnumerableSet.UintSet private betIds;

    BetFundPool public immutable betFundPool;

    mapping(uint256 => RoomData) private roomDatas;

    mapping(uint256 => BetData[]) private betDatas;

    mapping(address => AccountData) private accountData;

    event BetSingleCreated(uint256 betId, RoomDataParam RoomDataParam);
    event Bet(uint256 betId, address account);
    event Settlement(uint256 betId, address betWin, address betLose);
    event DecodeBetDatas(uint256 betId, uint256[][] decodeData);

    event Deposit(address indexed account, uint256 amount);
    event Withdraw(address indexed account, uint256 amount);

    error IncorrectPayment(uint256 msgValue, uint256 betPrice);

    error NotActive(
        uint256 currentTimestamp,
        uint256 startTimestamp,
        uint256 endTimestamp
    );

    constructor() {
        betFundPool = new BetFundPool();
    }

    function createBet(
        RoomDataParam calldata roomDataParam,
        bytes calldata betData
    ) external override noDelegateCall {
        betId = betId.add(1);

        betIds.add(betId);

        roomDatas[betId] = RoomData({
            startTime: roomDataParam.startTime,
            endTime: roomDataParam.endTime,
            betPrice: roomDataParam.betPrice,
            betToken: roomDataParam.betToken,
            status: 0,
            betWin: address(0),
            betLoses: address(0)
        });
        bet(betId, betData);

        emit BetSingleCreated(betId, roomDataParam);
    }

    function bet(uint256 id, bytes calldata betData) public nonReentrant override {
        require(betIds.contains(id), "bet id not exist");

        RoomData memory roomData = roomDatas[id];

        require(betDatas[betId].length < 2, "bet account length max");

        if (betDatas[id].length == 1) {
            require(msg.sender != betDatas[id][0].account, "you can't play");
            require(accountData[msg.sender].level == accountData[betDatas[id][0].account].level, "level not equal");
        }

        if (betDatas[betId].length > 0) {
            _checkActive(roomData.startTime, roomData.endTime);
        }

        betFundPool.bet(
            betId,
            msg.sender,
            roomData.betToken,
            roomData.betPrice
        );

        _setBetData(id, msg.sender, betData);

        emit Bet(id, msg.sender);
    }

    function settlement(uint256 id) external onlyOwner() nonReentrant {
        RoomData storage roomData = roomDatas[id];

        if (betDatas[id].length == 2) {
            address bet0Account = betDatas[id][0].account;
            address bet1Account = betDatas[id][1].account;

            uint256[] memory bet0Data = betDatas[id][0].decodeBetData;
            uint256[] memory bet1Data = betDatas[id][1].decodeBetData;
            require(
                bet0Data.length == bet1Data.length,
                "settlement bet data length !="
            );
            // 石头 0 剪刀 1 布 2
            uint256 bet0Wins = 0;
            uint256 bet1Wins = 1;

            for (uint256 i = 0; i < bet0Data.length; i++) {
                if (bet0Data[i] == 0 && bet1Data[i] == 1) {
                    // Bet 0 wins (石头 vs 剪刀)
                    bet0Wins++;
                } else if (bet0Data[i] == 1 && bet1Data[i] == 2) {
                    // Bet 0 wins (剪刀 vs 布)
                    bet0Wins++;
                } else if (bet0Data[i] == 2 && bet1Data[i] == 0) {
                    // Bet 0 wins (布 vs 石头)
                    bet0Wins++;
                } else if (bet1Data[i] == 0 && bet0Data[i] == 1) {
                    // Bet 1 wins (石头 vs 剪刀)
                    bet1Wins++;
                } else if (bet1Data[i] == 1 && bet0Data[i] == 2) {
                    // Bet 1 wins (剪刀 vs 布)
                    bet1Wins++;
                } else if (bet1Data[i] == 2 && bet0Data[i] == 0) {
                    // Bet 1 wins (布 vs 石头)
                    bet1Wins++;
                }
            }

            if (bet0Wins > bet1Wins) {
                // Bet 0 wins more times
                roomData.betWin = bet0Account;
                roomData.betLoses = bet1Account;

                accountData[bet0Account].level++;
                accountData[bet1Account].level = 0;

                betFundPool.settlementWin(id, bet0Account, roomData.betToken);
            } else if (bet1Wins > bet0Wins) {
                // Bet 1 wins more times
                roomData.betWin = bet1Account;
                roomData.betLoses = bet0Account;

                accountData[bet1Account].level++;
                accountData[bet0Account].level = 0;

                betFundPool.settlementWin(id, bet1Account, roomData.betToken);
            } else {
                // It's a tie
                betFundPool.settlementDraw(
                    id,
                    bet0Account,
                    bet1Account,
                    roomData.betToken
                );
            }

            roomData.status = 1;

            emit Settlement(id, roomData.betWin, roomData.betLoses);
        } else if (betDatas[id].length == 1) {
            betFundPool.settlementWin(id, betDatas[id][0].account, roomData.betToken);
        } else {
            revert("betDatas length error");
        }
    }

    function decodeBetDatas(
        uint256 id,
        uint256[][] calldata decodeData
    ) external onlyOwner() nonReentrant {
        for (uint256 i = 0; i < betDatas[id].length; i++) {
            betDatas[id][i].decodeBetData = decodeData[i];
        }
        emit DecodeBetDatas(id, decodeData);
    }

    /**
     * @notice Check that the drop stage is active.
     *
     * @param startTime The drop stage start time.
     * @param endTime   The drop stage end time.
     */
    function _checkActive(uint256 startTime, uint256 endTime) internal view {
        if (
            _cast(block.timestamp < startTime) |
                _cast(block.timestamp > endTime) ==
            1
        ) {
            // Revert if the drop stage is not active.
            revert NotActive(block.timestamp, startTime, endTime);
        }
    }

    /**
     * @dev Internal pure function to cast a `bool` value to a `uint256` value.
     *
     * @param b The `bool` value to cast.
     *
     * @return u The `uint256` value.
     */
    function _cast(bool b) internal pure returns (uint256 u) {
        assembly {
            u := b
        }
    }

    function _setBetData(
        uint256 id,
        address account,
        bytes calldata data
    ) internal {
        betDatas[id].push(
            BetData({
                account: account,
                data: data,
                decodeBetData: new uint256[](0)
            })
        );
    }

    function getBetIds() external override view returns (uint256[] memory) {
        return betIds.values();
    }

    function getBetDatas(uint id) external override view returns (BetData[] memory) {
        return betDatas[id];
    }

    function getRoomData(uint id) external override view returns (RoomData memory) {
        return roomDatas[id];
    }

    function getAccountData(
        address account
    ) external override view returns (AccountData memory) {
        return accountData[account];
    }

    function getRoomLength() external override view returns (uint256) {
        return betIds.length();
    }
}
