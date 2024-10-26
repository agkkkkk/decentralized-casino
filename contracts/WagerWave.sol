// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

error UnAuthorizedGame();

/// @title WagerWave Contract
/// @author Anurag Chemban
/// @notice This contract is responsible for managing casino game contracts and supported tokens.
/// @dev This contract serves as a registry for authorized casino game contracts and tokens, ensuring only approved contracts and tokens can be used in the ecosystem.
contract WagerWave is Ownable {
    bool public wagerWaveStatus = true;

    uint256 fee; // wagerwave contract fee

    mapping(address => bool) game;

    address[] supportedToken;

    /// checks whether the caller is an authorized game.
    /// @dev Reverts with `UnauthorizedGame` if the caller is not authorized.
    modifier onlyAuthorizedGame() {
        if (game[msg.sender]) {
            revert UnAuthorizedGame();
        }
        _;
    }

    constructor() Ownable(msg.sender) {}

    /// @notice Adds a new casino game contract.
    /// @dev Only callable by the contract owner. Ensures the game contract is authorized to be used in the casino ecosystem.
    /// @param _gameAddress The address of the game contract to add.
    function addGame(address _gameAddress) external onlyOwner {
        game[_gameAddress] = true;
    }

    /// @notice Removes a casino game contract.
    /// @dev Only callable by the contract owner. Prevents the game contract from further interaction within the ecosystem.
    /// @param _gameAddress The address of the game contract to remove.
    function removeGame(address _gameAddress) external onlyOwner {
        game[_gameAddress] = false;
    }

    /// @notice Adds a new token to the list of supported tokens.
    /// @dev Only callable by the contract owner. Allows games to use the specified token.
    /// @param _tokenAddress The address of the token to add to the supported list.
    function addSupportedToken(address _tokenAddress) external onlyOwner {
        for (uint256 i = 0; i < supportedToken.length; i++) {
            if (_tokenAddress == supportedToken[0]) {
                return;
            }
        }

        supportedToken.push(_tokenAddress);
    }

    /// @notice Removes a token from the list of supported tokens.
    /// @dev Only callable by the contract owner. Ensures that removed tokens are no longer valid for game transactions.
    /// @param _tokenAddress The address of the token to remove from the supported list.
    function removeSupportedToken(address _tokenAddress) external onlyOwner {
        for (uint256 i = 0; i < supportedToken.length; i++) {
            if (_tokenAddress == supportedToken[i]) {
                supportedToken[i] = supportedToken[supportedToken.length - 1];
                supportedToken.pop();

                return;
            }
        }
    }
}
