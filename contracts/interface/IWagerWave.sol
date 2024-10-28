// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

interface IWagerWave {
    function placeBet(address player, uint256 amount, address token, uint256 winnableAmount) external;

    function isTokenSupported(address _token) external returns(bool);
}
 