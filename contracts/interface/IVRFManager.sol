// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;
interface IVRFManager {
    function requestRandomNumber() external returns (uint256);
}