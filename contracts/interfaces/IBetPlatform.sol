// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import { RoomData, BetData, AccountData, RoomDataParam } from '../lib/Struct.sol';
// Uncomment this line to use console.log
// import "hardhat/console.sol";

interface IBetPlatform {

    function createBet(
        RoomDataParam calldata roomDataParam,
        bytes calldata betData
    ) external;

    function bet(uint256 id, bytes calldata betData) external;


    function getBetIds() external view returns (uint256[] memory);

    function getBetDatas(uint id) external view returns (BetData[] memory);

    function getRoomData(uint id) external view returns (RoomData memory);

    function getAccountData(
        address account
    ) external view returns (AccountData memory);

    function getRoomLength() external view returns (uint256);
}
