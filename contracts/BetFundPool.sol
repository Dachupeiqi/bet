// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IBetFundPool.sol";

contract BetFundPool is IBetFundPool, Ownable, ReentrancyGuard{
    using SafeMath for uint256;

    // 存储支持的代币列表
    address[] private supportedTokens;

    // 存储每种代币的地址和余额
    mapping(address => uint256) private tokenBalances;

    mapping(address => mapping(address => uint256)) private balances;

    mapping(uint256 => mapping(address => uint256)) private betBalances;

    event Deposit(address indexed account, address tokenAddress, uint256 amount, uint256 timestamp);
    event Withdraw(address indexed account, address tokenAddress, uint256 amount, uint256 timestamp);
    event Bet(address indexed account, uint256 betId, address betToken, uint256 betPrice);
    event Settlement0(uint256 betId, address betWin, address betToken, uint256 betBalance);
    event Settlement1(uint256 betId, address account0, address account1, address betToken, uint256 betBalance);

    // 添加支持的代币
    function addSupportedToken(address tokenAddress) external override onlyOwner {
        require(tokenAddress != address(0), "Invalid token address");
        require(tokenBalances[tokenAddress] == 0, "Token is already supported");

        supportedTokens.push(tokenAddress);
    }

    function deposit(address tokenAddress, uint256 amount) external override nonReentrant {
        require(tokenAddress != address(0), "Invalid token address");
        require(amount > 0, "Amount must be greater than zero");

        IERC20 token = IERC20(tokenAddress);
        bool success = token.transferFrom(msg.sender, address(this), amount);
        require(success, "Token transfer failed");

        tokenBalances[tokenAddress] = tokenBalances[tokenAddress].add(amount);
        balances[msg.sender][tokenAddress] = balances[msg.sender][tokenAddress].add(amount);

        emit Deposit(msg.sender, tokenAddress, amount, block.timestamp);
    }

    function withdraw(address tokenAddress, uint256 amount) external override nonReentrant {
        require(tokenAddress != address(0), "Invalid token address");
        require(amount > 0, "Amount must be greater than zero");
        require(balances[msg.sender][tokenAddress] >= amount, "Insufficient balance");

        IERC20 token = IERC20(tokenAddress);
        bool success = token.transfer(msg.sender, amount);
        require(success, "Token transfer failed");

        tokenBalances[tokenAddress] = tokenBalances[tokenAddress].sub(amount);
        balances[msg.sender][tokenAddress] = balances[msg.sender][tokenAddress].sub(amount);
        emit Withdraw(msg.sender, tokenAddress, amount, block.timestamp);
    }

    function bet(uint256 betId, address betAccount, address betToken, uint256 betPrice) external override nonReentrant {
        require(balances[betAccount][betToken] >= betPrice,"Insufficient balance");

        balances[betAccount][betToken] = balances[betAccount][betToken].sub(betPrice);
        betBalances[betId][betToken] = betBalances[betId][betToken].add(betPrice);

        emit Bet(betAccount, betId, betToken, betPrice);
    }

    function settlementWin(uint256 betId, address betWin, address betToken) external override onlyOwner nonReentrant {
        uint256 betBalance = betBalances[betId][betToken];
        balances[betWin][betToken] = balances[betWin][betToken].add(betBalance);

        emit Settlement0(betId, betWin, betToken, betBalance);
    }

    function settlementDraw(uint256 betId, address account0, address account1, address betToken) external override onlyOwner nonReentrant {
        uint256 betBalance = betBalances[betId][betToken].div(2);
        balances[account0][betToken] = balances[account0][betToken].add(betBalance);
        balances[account1][betToken] = balances[account1][betToken].add(betBalance);

        emit Settlement1(betId, account0, account1, betToken, betBalance);
    }

    function getUserTokenBalance(address user, address tokenAddress) external override view returns (uint256) {
        return balances[user][tokenAddress];
    }

    function getTokenBalance(address tokenAddress) external view override returns (uint256) {
        return tokenBalances[tokenAddress];
    }

    function getSupportedTokens() external override view returns (address[] memory) {
        return supportedTokens;
    }
}