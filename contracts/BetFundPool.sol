// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IBetFundPool.sol";

// 投注基金池合约，用于管理支持的代币、用户余额以及投注流水记录
contract BetFundPool is IBetFundPool, Ownable, ReentrancyGuard{
    using SafeMath for uint256;

    // 存储支持的代币列表
    address[] private supportedTokens;

    // 存储每种代币的地址和余额
    mapping(address => uint256) private tokenBalances;

     // 存储用户在不同代币上的余额
    mapping(address => mapping(address => uint256)) private balances;

     // 存储每个投注房间的代币投注总额
    mapping(uint256 => mapping(address => uint256)) private betBalances;

    event Deposit(address indexed account, address tokenAddress, uint256 amount, uint256 timestamp);
    event Withdraw(address indexed account, address tokenAddress, uint256 amount, uint256 timestamp);
    event Bet(address indexed account, uint256 betId, address betToken, uint256 betPrice);
    event Settlement0(uint256 betId, address betWin, address betToken, uint256 betBalance);
    event Settlement1(uint256 betId, address account0, address account1, address betToken, uint256 betBalance);

    // 存储代币资金流动记录
     struct TokenFundFlowRecord {
        address account;       
        address token;
        uint256 amount;
        uint256 timestamp;
        string descript;
    }

    TokenFundFlowRecord[] private tokenFundFlowRecords;

    // 添加支持的代币   1版这里没有用到
    function addSupportedToken(address tokenAddress) external override onlyOwner {
        require(tokenAddress != address(0), "Invalid token address");
        require(tokenBalances[tokenAddress] == 0, "Token is already supported");    // 1版这里有问题，自我觉得怪怪的

        supportedTokens.push(tokenAddress);
    }

        // 存款函数，将代币存入合约
    function deposit(address tokenAddress, uint256 amount) external override nonReentrant {
        require(tokenAddress != address(0), "Invalid token address");
        require(amount > 0, "Amount must be greater than zero");

    // 调用 ERC20 合约的转账方法，将代币转入合约
        IERC20 token = IERC20(tokenAddress);
        bool success = token.transferFrom(msg.sender, address(this), amount);
        require(success, "Token transfer failed");

         string memory  descipt = "token deposit in fundPool ";
        // 记录资金流动记录
        storeUserTokenFundFlowRecord(msg.sender, tokenAddress, amount, block.timestamp, descipt);

        // 更新合约和用户余额
        tokenBalances[tokenAddress] = tokenBalances[tokenAddress].add(amount);
        balances[msg.sender][tokenAddress] = balances[msg.sender][tokenAddress].add(amount);
       
        emit Deposit(msg.sender, tokenAddress, amount, block.timestamp);
    }

    // 提款函数，从合约提取代币到用户钱包
    function withdraw(address tokenAddress, uint256 amount) external override nonReentrant {
        require(tokenAddress != address(0), "Invalid token address");
        require(amount > 0, "Amount must be greater than zero");
        require(balances[msg.sender][tokenAddress] >= amount, "Insufficient balance");

        // 调用 ERC20 合约的转账方法，将代币转出合约
        IERC20 token = IERC20(tokenAddress);
        bool success = token.transfer(msg.sender, amount);
        require(success, "Token transfer failed");

        string memory  descipt = "token withdraw in fundPool ";
         // 记录资金流动记录
        storeUserTokenFundFlowRecord(msg.sender, tokenAddress, amount, block.timestamp,descipt);

          // 更新合约和用户余额
        tokenBalances[tokenAddress] = tokenBalances[tokenAddress].sub(amount);
        balances[msg.sender][tokenAddress] = balances[msg.sender][tokenAddress].sub(amount);
        emit Withdraw(msg.sender, tokenAddress, amount, block.timestamp);
    }

     // 用户下注函数，从用户余额扣除下注金额
    function bet(uint256 roomId, address betAccount, address betToken, uint256 betPrice) external override nonReentrant {
        require(balances[betAccount][betToken] >= betPrice,"Insufficient balance");

          // 更新用户和房间的投注余额
        balances[betAccount][betToken] = balances[betAccount][betToken].sub(betPrice);
        betBalances[roomId][betToken] = betBalances[roomId][betToken].add(betPrice);

         string memory  descipt = "user bet the token";
          // 记录资金流动记录
        storeUserTokenFundFlowRecord(betAccount, betToken, betPrice, block.timestamp,descipt);

        emit Bet(betAccount, roomId, betToken, betPrice);
    }

      // 胜利结算函数，将胜利的用户的投注额返还
    function settlementWin(uint256 roomId, address betWin, address betToken) external override onlyOwner nonReentrant {
        uint256 betBalance = betBalances[roomId][betToken];
        balances[betWin][betToken] = balances[betWin][betToken].add(betBalance);

         string memory  descipt = "user win the token";
          // 记录资金流动记录
        storeUserTokenFundFlowRecord(betWin, betToken, betBalance, block.timestamp,descipt);

        emit Settlement0(roomId, betWin, betToken, betBalance);
    }

     // 平局结算函数，将投注额平分返还给两位用户
    function settlementDraw(uint256 roomId, address account0, address account1, address betToken) external override onlyOwner nonReentrant {
        uint256 betBalance = betBalances[roomId][betToken].div(2);
        balances[account0][betToken] = balances[account0][betToken].add(betBalance);
        balances[account1][betToken] = balances[account1][betToken].add(betBalance);

        // 记录资金流动记录
        if (account0 == msg.sender || account1 == msg.sender) {
             string memory  descipt = "user draw return the token";
            // 仅记录登录账户的资金流动记录
            storeUserTokenFundFlowRecord(account0, betToken, betBalance, block.timestamp, descipt);
            storeUserTokenFundFlowRecord(account1, betToken, betBalance, block.timestamp, descipt);
        }

        emit Settlement1(roomId, account0, account1, betToken, betBalance);
    }

     // 查询用户在某代币上的余额
    function getUserTokenBalance(address user, address tokenAddress) external override view returns (uint256) {
        return balances[user][tokenAddress];
    }

     // 查询某代币在合约中的余额
    function getTokenBalance(address tokenAddress) external view override returns (uint256) {
        return tokenBalances[tokenAddress];
    }

     // 查询支持的代币列表
    function getSupportedTokens() external override view returns (address[] memory) {
        return supportedTokens;
    }

     // 查询特定用户的全部资金流动记录
    function getUserTokenFundFlowRecords(address account) external view  returns (TokenFundFlowRecord[] memory) {
        uint256 userRecordCount = 0;
        
        for (uint256 i = 0; i < tokenFundFlowRecords.length; i++) {
            if (tokenFundFlowRecords[i].account == account) {
                userRecordCount++;
            }
        }

        TokenFundFlowRecord[] memory userRecords = new TokenFundFlowRecord[](userRecordCount);
        uint256 currentIndex = 0;

        for (uint256 i = 0; i < tokenFundFlowRecords.length; i++) {
            if (tokenFundFlowRecords[i].account == account) {
                userRecords[currentIndex] = tokenFundFlowRecords[i];
                currentIndex++;
            }
        }

        return userRecords;
    }
      // 记录资金流动记录
    function storeUserTokenFundFlowRecord(address account, address token, uint256 amount, uint256 timestamp,string memory descript) internal {
      tokenFundFlowRecords.push(TokenFundFlowRecord({
            account: account,
            token: token,
            amount: amount,
            timestamp: timestamp,
            descript: descript
        }));

    }


}