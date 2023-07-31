// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

// Uncomment this line to use console.log
// import "hardhat/console.sol";

interface IBetFundPool {
    function addSupportedToken(address tokenAddress) external;

    function deposit(address tokenAddress, uint256 amount) external;

    function withdraw(address tokenAddress, uint256 amount) external;

    function bet(uint256 betId, address betAccount, address betToken, uint256 betPrice) external;

    function settlementWin(uint256 betId, address betWin, address betToken) external;

    function settlementDraw(uint256 betId, address account0, address account1, address betToken) external;

    function getUserTokenBalance(address user, address tokenAddress) external view returns (uint256);

    function getTokenBalance(address tokenAddress) external view returns (uint256);

    function getSupportedTokens() external view returns (address[] memory);
}
