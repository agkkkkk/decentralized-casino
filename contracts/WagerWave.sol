// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title WagerWave Contract
/// @author AGK
/// @notice This contract is responsible for managing casino game contracts and supported tokens.
/// @dev This contract serves as a registry for authorized casino game contracts and tokens, ensuring only approved contracts and tokens can be used in the ecosystem.
contract WagerWave is Ownable, ReentrancyGuard {
    error UnAuthorizedGame();
    error WagerWaveNotLive();

    bool public wagerWaveStatus = true;

    uint256 fee; // wagerwave contract fee

    mapping(address => bool) game;

    address[] public supportedToken;

    /// checks whether the caller is an authorized game.
    /// @dev Reverts with `UnauthorizedGame` if the caller is not authorized.
    modifier onlyAuthorizedGame() {
        if (!game[msg.sender]) {
            revert UnAuthorizedGame();
        }
        _;
    }

    /// @notice Ensures the WagerWave platform is live before function execution.
    /// @dev Reverts with `WagerWaveNotLive` if the platform is paused.
    modifier isWagerWaveLive() {
        if (!wagerWaveStatus) {
            revert WagerWaveNotLive();
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
            if (_tokenAddress == supportedToken[i]) {
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

    /// @notice Checks if a given token is supported in the casino.
    /// @param _token The address of the token to check.
    /// @return bool True if the token is supported, false otherwise.
    function isTokenSupported(address _token) external view returns (bool) {
        for (uint256 i = 0; i < supportedToken.length; i++) {
            if (_token == supportedToken[i]) {
                return true;
            }
        }
        return false;
    }

    /// @notice Checks if a given game is supported.
    /// @param _game The address of the token to check.
    /// @return bool True if the game is supported, false otherwise.
    function isGameSupported(address _game) external view returns (bool) {
        return game[_game];
    }

    /// @notice manages transferring tokens for bet.
    /// @param _player The address of the player.
    /// @param _amount The amount of tokens being wagered.
    /// @param _token The address of the token being used for the bet.
    /// @param _winnableAmount The maximum amount that the player can win.
    function placeBet(address _player, uint256 _amount, address _token, uint256 _winnableAmount)
        external
        payable
        isWagerWaveLive
        nonReentrant
        onlyAuthorizedGame
    {
        if (_token == address(0)) {
            require(_amount == msg.value);
        } else {
            IERC20(_token).transferFrom(_player, address(this), _amount);
        }
    }

    /// @notice Settles a player's bet.
    /// @dev Transfers winnings to the player if `_win` is `true`.
    /// @param _player The address of the player whose bet is being settled.
    /// @param _amount The amount the player initially bet.
    /// @param _token The address of the token used for the bet. If zero address, native token is used.
    /// @param _winnableAmount The amount the player can win.
    /// @param _win Boolean indicating if the player won (`true`) or lost (`false`).
    function settleBet(address _player, uint256 _amount, address _token, uint256 _winnableAmount, bool _win)
        external
        isWagerWaveLive
        nonReentrant
        onlyAuthorizedGame
    {
        if (_win) {
            if (_token == address(0)) {
                payable(_player).transfer(_winnableAmount);
            } else {
                IERC20(_token).transfer(_player, _winnableAmount);
            }
        }
    }
}
