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

// 请取消注释以下这一行，以便使用 console.log 进行调试
import "hardhat/console.sol";

contract BetPlatform is IBetPlatform, NoDelegateCall, Ownable, ReentrancyGuard {
    using SafeMath for uint256;

    using EnumerableSet for EnumerableSet.UintSet;

    using EnumerableSet for EnumerableSet.AddressSet;

    uint256 private roomId;

    // 使用 EnumerableSet 来管理房间 ID 集合
    EnumerableSet.UintSet private roomIds;

    // 不可变的投注基金池合约
    BetFundPool public immutable betFundPool;

    // 存储自定义策略数据结构
     struct CustomStrategy {
        uint256 strategyId; // 策略id
        address creator; // 策略创建者的地址
        bytes data;      // 策略数据
    }
    //   // 使用数组来存储自定义策略
    // CustomStrategy[] private customStrategies;

     // 存储每个房间的数据
    mapping(uint256 => RoomData) private roomDatas;

    // 存储每个房间的投注数据
    mapping(uint256 => BetData[]) private betDatas;

    // 存储每个用户的账户数据
    mapping(address => AccountData) private accountData;

    // 存储每个用户的自定义策略数据
    mapping(address => CustomStrategy[]) private customStrategies;

    // 存储每个用户拥有的自定义策略数量
    mapping(address => uint256) private customStrategyCounts;

    // 定义事件，用于日志记录、

    // 用于记录当创建一个新的投注房间时的信息
    event RoomCreated(uint256 roomId, CreatRoomParam creatRoomParam);

    // 当有人在投注房间进行投注时，这个事件会被触发
    event Bet(uint256 roomId, address account);

    // 当投注房间的结果被结算时，这个事件会被触发
    event Settlement(uint256 roomId, address betWin, address betLose);
    
    // 当投注数据被解码时，这个事件会被触发。
    event DecodeBetDatas(uint256 roomId, uint256[][] decodeData);

    // 当用户向合约存入资金时，这个事件会被触发
    event Deposit(address indexed account, uint256 amount);

    // 当用户从合约中提取资金时，这个事件会被触发。
    event Withdraw(address indexed account, uint256 amount);

    // 当存储自定义策略时触发
    event CustomStrategyStored(uint256 indexed strategyId, address indexed creator);


    // 定义错误类型，用于异常处理
    error IncorrectPayment(uint256 msgValue, uint256 betPrice);
    error NotActive(uint256 currentTimestamp, uint256 startTimestamp, uint256 endTimestamp);

     // 构造函数，在合约部署时被调用
    constructor() {
         // 创建一个新的投注基金池合约，并将其设置为不可变
        betFundPool = new BetFundPool();
    }

    

     /**
     * @notice 创建一个新的投注房间。
     *
     * @param createRoomParam 房间参数。
     * @param betData 参与的策略
     */
    function createRoom(
        CreatRoomParam calldata createRoomParam,
        bytes calldata betData
    ) external override noDelegateCall {
        roomId = roomId.add(1);

          // 将新的房间 ID 添加到房间 ID 集合中
        roomIds.add(roomId);

          // 初始化房间数据
        roomDatas[roomId] = RoomData({
            startTime: createRoomParam.startTime,
            endTime: createRoomParam.endTime,
            betPrice: createRoomParam.betPrice,
            betToken: createRoomParam.betToken,
            status: 0,          // 未结算
            betWin: address(0),
            betLoses: address(0)
        });

        // 进行投注
        bet(roomId, betData);

        // 触发 RoomCreated 事件，记录房间创建的日志
        emit RoomCreated(roomId,createRoomParam );
    }

    /**
     * @notice 在投注房间进行投注。
     *
     * @param roomId 投注房间的ID。
     * @param betData 投注数据。
     */

    function bet(uint256 roomId, bytes calldata betData) public nonReentrant override {
           // 确保房间 ID 存在于房间 ID 集合中
        require(roomIds.contains(roomId), "bet id not exist");

         // 获取房间数据
        RoomData memory roomData = roomDatas[roomId];

         // 确保投注账户数量未超过上限
        require(betDatas[roomId].length < 2, "bet account length max");

        // 如果已有一个投注账户，确保不是同一个账户并且等级相等
        if (betDatas[roomId].length == 1) {         // 这里为确保已经有一个投注帐户
            require(msg.sender != betDatas[roomId][0].account, "you can't play");
            require(accountData[msg.sender].level == accountData[betDatas[roomId][0].account].level, "level not equal");
        }

        // 如果已有投注数据，检查投注阶段是否有效 投注阶段用来检验时间是否在这个范围内，用户只能在这个时间范围内进行投注。
        if (betDatas[roomId].length > 0) {
            _checkActive(roomData.startTime, roomData.endTime);
        }

           // 调用投注基金池合约进行投注
        betFundPool.bet(
            roomId,
            msg.sender,
            roomData.betToken,
            roomData.betPrice
        );

         // 设置投注数据
        _setBetData(roomId, msg.sender, betData);

         // 触发 Bet 事件，记录投注的日志
        emit Bet(roomId, msg.sender);
    }

     /**
     * @notice 结算投注房间的结果。
     *
     * @param roomId 要结算的投注房间的ID。
     */
    function settlement(uint256 roomId) external onlyOwner() nonReentrant {

          // 获取房间数据的引用
        RoomData storage roomData = roomDatas[roomId];

        // 检查是否有两个投注帐户
        if ( [roomId].length == 2) {
            address bet0Account = betDatas[roomId][0].account;
            address bet1Account = betDatas[roomId][1].account;

            // 这里为 玩家1 的投注策略
            uint256[] memory bet0Data = betDatas[roomId][0].decodeBetData;
            // 这里为 玩家2 的投注策略
            uint256[] memory bet1Data = betDatas[roomId][1].decodeBetData;

            // 确保投注数据长度一致
            require(
                bet0Data.length == bet1Data.length,
                "settlement bet data length !="
            );
            
            // 根据投注结果确定赢家
            // 代表两个玩家赢得次数
            uint256 bet0Wins = 0;
            uint256 bet1Wins = 0;       // 1版需修改的地方

             // 遍历每个投注数据，判断胜利者
            for (uint256 i = 0; i < bet0Data.length; i++) {
                // // 石头 0 剪刀 1 布 2]
                if (bet0Data[i] == 0 && bet1Data[i] == 1) {
                    // 投注者 0 获胜（石头 vs 剪刀）
                    bet0Wins++;
                } else if (bet0Data[i] == 1 && bet1Data[i] == 2) {
                    // 投注者 0 获胜（剪刀 vs 布）
                    bet0Wins++;
                } else if (bet0Data[i] == 2 && bet1Data[i] == 0) {
                    // 投注者 0 获胜（布 vs 石头）
                    bet0Wins++;
                } else if (bet1Data[i] == 0 && bet0Data[i] == 1) {
                    // 投注者 1 获胜（石头 vs 剪刀）
                    bet1Wins++;
                } else if (bet1Data[i] == 1 && bet0Data[i] == 2) {
                    // 投注者 1 获胜（剪刀 vs 布）
                    bet1Wins++;
                } else if (bet1Data[i] == 2 && bet0Data[i] == 0) {
                    // 投注者 1 获胜（布 vs 石头）
                    bet1Wins++;
                }
            }

            // 根据胜利者结算
            if (bet0Wins > bet1Wins) {
                 // 投注者 0 获胜
                roomData.betWin = bet0Account;
                roomData.betLoses = bet1Account;

                // 提升投注者 0 的等级，重置投注者 1 的等级
                accountData[bet0Account].level++;
                accountData[bet1Account].level = 0;

                // 调用投注基金池合约进行结算
                betFundPool.settlementWin(roomId, bet0Account, roomData.betToken);
            } else if (bet1Wins > bet0Wins) {
                // 投注者 1 获胜
                roomData.betWin = bet1Account;
                roomData.betLoses = bet0Account;

                // 提升投注者 1 的等级，重置投注者 0 的等级
                accountData[bet1Account].level++;
                accountData[bet0Account].level = 0;

                // 调用投注基金池合约进行结算
                betFundPool.settlementWin(roomId, bet1Account, roomData.betToken);
            } else {
                // 平局
                betFundPool.settlementDraw(
                    roomId,
                    bet0Account,
                    bet1Account,
                    roomData.betToken
                );
            }

            // 更新房间状态为已结算
            roomData.status = 1;

        } else if (betDatas[roomId].length == 1) {
             // 如果只有一个投注账户，则直接将其设置为获胜者
            betFundPool.settlementWin(roomId, betDatas[roomId][0].account, roomData.betToken);
        } else {
             // 投注数据异常
            revert("betDatas length error");
        }
        // 触发结算事件，记录结算的日志
        emit Settlement(roomId, roomData.betWin, roomData.betLoses);
    }

        /**
     * @notice 解码投注数据。
     *
     * @param roomId 房间的ID。
     * @param decodeData 解码后的投注数据。
     */

    function decodeBetDatas(
        uint256 roomId,
        uint256[][] calldata decodeData
    ) external onlyOwner() nonReentrant {
         // 遍历每个投注数据，更新解码后的数据
        for (uint256 i = 0; i < betDatas[roomId].length; i++) {
            betDatas[roomId][i].decodeBetData = decodeData[i];
        }
         // 触发解码事件，记录解码的日志
        emit DecodeBetDatas(roomId, decodeData);
    }

      /**
     * @dev 内部函数，检查投注阶段是否仍然有效。
     *
     * @param startTime 投注阶段开始时间。
     * @param endTime 投注阶段结束时间。
     */
    function _checkActive(uint256 startTime, uint256 endTime) internal view {
           // 检查当前时间是否在投注阶段内
        if (
            _cast(block.timestamp < startTime) |
                _cast(block.timestamp > endTime) ==
            1
        ) {
            // 如果不在投注阶段内，抛出异常
            revert NotActive(block.timestamp, startTime, endTime);
        }
    }

     /**
     * @dev 内部纯函数，将布尔值转换为 uint256 类型的值。
     *
     * @param b 要转换的布尔值。
     * @return u 转换后的 uint256 值。
     */
    function _cast(bool b) internal pure returns (uint256 u) {
        assembly {
            u := b
        }
    }


    /**
     * @dev 内部函数，设置投注数据。
     *
     * @param id 房间的ID。
     * @param account 投注账户。
     * @param data 原始投注数据。
     */
    function _setBetData(
        uint256 id,
        address account,
        bytes calldata data
    ) internal {
           // 向指定房间添加投注数据
        betDatas[id].push(
            BetData({
                account: account,
                data: data,
                decodeBetData: new uint256[](0)
            })
        );
    }

     /**
     * @notice 获取所有投注房间的ID。
     *
     * @return 一个房间ID的数组。
     */
    function getRoomIds() external override view returns (uint256[] memory) {
         // 返回所有投注房间的 ID 集合
        return roomIds.values();
    }

       /**
     * @notice 获取指定房间的投注数据。
     *
     * @param id 房间的ID。
     * @return 一个 BetData 数组。
     */
    function getBetDatas(uint id) external override view returns (BetData[] memory) {
         // 返回指定房间的投注数据
        return betDatas[id];
    }


    /**
     * @notice 获取指定房间的数据。
     *
     * @param id 房间的ID。
     * @return 房间的 RoomData。
     */
    function getRoomData(uint id) external override view returns (RoomData memory) {
         // 返回指定房间的数据
        return roomDatas[id];
    }

      /**
     * @notice 获取指定账户的账户数据。
     *
     * @param account 账户的地址。
     * @return 账户的 AccountData。
     */
    function getAccountData(
        address account
    ) external override view returns (AccountData memory) {
        return accountData[account];
    }

     /**
     * @notice 获取投注房间的数量。
     *
     * @return 房间的数量。
     */
    function getRoomLength() external override view returns (uint256) {
         // 返回指定账户的账户数据
        return roomIds.length();
    }

    
    /**
    * @notice 存储自定义策略。
    *
    * @param betData 要存储的策略数据。
    */
    function storeCustomStrategy(bytes calldata betData) external {
           // 获取当前用户已有的自定义策略数量 + 1，作为新策略的ID
        uint256 strategyId = customStrategyCounts[msg.sender] + 1;
        // 将新的自定义策略添加到用户的策略数组中
        customStrategies[msg.sender].push(CustomStrategy({
            strategyId: strategyId,
            creator: msg.sender,
            data: betData
        }));
        // 增加用户拥有的自定义策略数量
        customStrategyCounts[msg.sender]++;
         // 触发自定义策略存储事件
        emit CustomStrategyStored(strategyId, msg.sender);
    }
    
    /**
    * @return 用户策略数量。
    */
    function getCustomStrategyCount() external view returns (uint256) {
        return customStrategyCounts[msg.sender];
    }

    /**
    * @notice 根据策略ID获取自定义策略。
    *
    * @param strategyId 策略ID。
    * @return 策略创建者地址和策略数据。
    */
    function getCustomStrategy(uint256 strategyId) external view returns (address, bytes memory) {
        // 确保策略ID在有效范围内
        require(strategyId > 0 && strategyId <= customStrategyCounts[msg.sender], "Invalid strategy ID");
        // 获取指定策略ID的自定义策略数据
        CustomStrategy memory strategy = customStrategies[msg.sender][strategyId - 1 ];
         // 返回策略创建者地址和策略数据
        return (strategy.creator, strategy.data);
    }

    
    /**
    * @notice 获取指定用户所有自定义策略的信息。
    *
    * @return 用户的自定义策略数组。
    */
    function getAllCustomStrategies() external view returns (CustomStrategy[] memory) {
         // 返回当前用户拥有的所有自定义策略数据
        return customStrategies[msg.sender];
    }

    
}
