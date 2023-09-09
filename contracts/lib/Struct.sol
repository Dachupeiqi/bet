// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

struct RoomData {
    uint256 startTime;
    uint256 endTime;
    uint256 betPrice;
    address betToken;
    uint256 status;
    address betWin;
    address betLoses;
}

struct CreatRoomParam {
    uint256 startTime;
    uint256 endTime;
    uint256 betPrice;
    address betToken;
}

struct AccountData {
    uint256 level;
}

struct BetData {
    address account;
    bytes data;
    uint256[] decodeBetData;
}

