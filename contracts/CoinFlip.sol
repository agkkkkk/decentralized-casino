// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import "./interface/IWagerWave.sol";
import "./interface/IVRFManager.sol";

/// @title Coinflip Betting Game
/// @author AGK
/// @notice This contract allows users to place a bet on a coin flip game.
/// @dev The contract uses chainlink VRF for randomness.
contract CoinFlip is Ownable, ReentrancyGuard {
    error CoinflipNotLive();
    error MaxBettableLimitExceed();
    error BetChoiceRangeExceed(uint256 _betChoice, uint256 _maxBetChoice);
    error TokenNotSupported();
    error NotVRFManager();

    event BetPlaced(
        uint256 indexed betId, address indexed player, uint256 amount, uint256 coins, uint256 choice, address token
    );

    event BetSettled(
        uint256 indexed betId,
        address indexed player,
        uint256 amount,
        uint256 coins,
        uint256 choice,
        uint256 outcome,
        uint256 winAmount,
        address token
    );

    IWagerWave wagerwave;
    IVRFManager vrfManager;

    bool public coinflipLive = true;
    uint256 constant MAX_COIN_BETTABLE = 4;

    struct TokenInfo {
        uint256 minBettableAmount;
        uint256 maxBettableAmount;
        uint256 houseEdge;
    }

    mapping(address => TokenInfo) public tokenInfo;

    struct Bet {
        uint8 coins;
        uint40 choice;
        uint40 outcome;
        uint168 blockNumber;
        uint128 amount;
        uint128 winAmount;
        address player;
        address token;
        bool isSettled;
    }

    Bet[] public bets;

    mapping(uint256 => uint256) public betMap;

    /// @notice Ensures that the game is live before allowing a function to execute.
    /// @dev Reverts with `CoinflipNotLive` if the game is not active.
    modifier isCoinflipLive() {
        if (!coinflipLive) {
            revert CoinflipNotLive();
        }
        _;
    }

    /// @notice Ensures that the token used in a bet is supported by WagerWave.
    /// @dev Reverts with `TokenNotSupported` if the token is not supported.
    modifier onlySupportedToken(address _token) {
        if (!wagerwave.isTokenSupported(_token)) {
            revert TokenNotSupported();
        }
        _;
    }

    /// @notice Ensures that the game is live before allowing a function to execute.
    /// @dev Reverts with `CoinflipNotLive` if the game is not active.
    modifier onlyVRFManager() {
        if (!(_msgSender() == address(vrfManager))) {
            revert NotVRFManager();
        }
        _;
    }

    constructor(address _vrfManager, address _wagerwave) Ownable(msg.sender) {
        vrfManager = IVRFManager(_vrfManager);
        wagerwave = IWagerWave(_wagerwave);
    }

    /// @notice updates the address of the WagerWave contract.
    /// @dev Only callable by the contract owner.
    /// @param _wagerWave The address of the WagerWave contract.
    function updateWagerWave(address _wagerWave) external onlyOwner {
        wagerwave = IWagerWave(_wagerWave);
    }

    /// @notice updates the address of the VRFManager contract.
    /// @dev Only callable by the contract owner.
    /// @param _vrfManager The address of the VRFManager contract.
    function updateVRFManager(address _vrfManager) external onlyOwner {
        vrfManager = IVRFManager(_vrfManager);
    }

    /// @notice Toggles the live status of the coin flip game.
    /// @dev Only callable by the contract owner.
    function toggleCoinflipLive() external onlyOwner {
        coinflipLive = !coinflipLive;
    }

    /// @notice Sets the minimum bet amount for a given token.
    /// @param _token The address of the token.
    /// @param _minAmount The minimum amount that can be bet.
    function setMinimumBetAmount(address _token, uint256 _minAmount) external onlyOwner onlySupportedToken(_token) {
        tokenInfo[_token].minBettableAmount = _minAmount;
    }

    /// @notice Sets the maximum bet amount for a given token.
    /// @param _token The address of the token.
    /// @param _maxAmount The maximum amount that can be bet.
    function setMaximumBetAmount(address _token, uint256 _maxAmount) external onlyOwner onlySupportedToken(_token) {
        tokenInfo[_token].maxBettableAmount = _maxAmount;
    }

    /// @notice Sets the house edge (fee percentage) for a given token.
    /// @param _token The address of the token.
    /// @param _houseEdge The house edge percentage in basis points (1% = 100).
    function setHouseEdge(address _token, uint256 _houseEdge) external onlyOwner onlySupportedToken(_token) {
        tokenInfo[_token].houseEdge = _houseEdge;
    }

    /// @notice Allows a player to place a bet on a coin flip game.
    /// @dev Validates bet parameters and uses WagerWave to transfer funds. Reverts on invalid choices or limits.
    /// @param _betToken The address of the token used to place the bet.
    /// @param _coins The number of coins to flip, capped at `MAX_COIN_BETTABLE`.
    /// @param _amount The amount of tokens wagered.
    /// @param _choice The player's choice (heads/tails) in binary form.
    /// @dev For a bet on 2 coins, where coin 1 is heads and coin 2 is tails, the choice can be represented in binary as 10, which equals 2 in decimal form.
    function placeBet(address _betToken, uint256 _coins, uint256 _amount, uint256 _choice)
        external
        payable
        nonReentrant
        isCoinflipLive
    {
        if (_coins > MAX_COIN_BETTABLE) {
            revert MaxBettableLimitExceed();
        }
        if (_choice >= 2 ** _coins) {
            revert BetChoiceRangeExceed(_choice, 2 ** _coins);
        }

        if (_betToken == address(0)) {
            _amount = msg.value;
        }

        uint256 winnableAmount = getWinnableAmount(_betToken, _amount, _coins);

        wagerwave.placeBet{value: msg.value}(msg.sender, _amount, _betToken, winnableAmount);

        uint256 betId = bets.length;

        uint256 requestId = vrfManager.requestRandomNumber();
        betMap[requestId] = betId;

        emit BetPlaced(betId, msg.sender, _amount, _coins, _choice, _betToken);

        bets.push(
            Bet({
                coins: uint8(_coins),
                choice: uint40(_choice),
                outcome: 0,
                blockNumber: uint168(block.number),
                amount: uint128(_amount),
                winAmount: uint128(winnableAmount),
                player: msg.sender,
                token: _betToken,
                isSettled: false
            })
        );
    }

    /// @notice Settles a bet using a Chainlink VRF request result.
    /// @dev Uses the VRF-generated random values to determine the outcome and calls `_settleBet` to handle the result.
    /// @param requestId The ID of the VRF request tied to the specific bet.
    /// @param values An array of random values generated by VRF, where `values[0]` is used to determine the outcome.
    function settleBet(uint256 requestId, uint256[] memory values) external onlyVRFManager {
        uint256 betId = betMap[requestId];

        _settleBet(betId, values[0]);
    }

    /// @notice Determines the outcome of a specific bet and settles it.
    /// @dev Calculates whether the player won or lost based on a random `value`, then updates the bet's status and calls `settleBet` on the `WagerWave` contract to distribute winnings.
    /// @param betId The ID of the bet being settled.
    /// @param value The random value provided to determine the outcome.
    function _settleBet(uint256 betId, uint256 value) private nonReentrant {
        Bet storage bet = bets[betId];

        uint256 amount = bet.amount;
        if (amount == 0 || bet.isSettled) {
            return;
        }

        address player = bet.player;
        address token = bet.token;
        uint256 choice = bet.choice;
        uint256 coins = bet.coins;

        uint256 outcome = value % (2 ** coins);
        uint256 winnableAmount = getWinnableAmount(token, amount, coins);
        uint256 winAmount = choice == outcome ? winnableAmount : 0;

        bet.isSettled = true;
        bet.winAmount = uint128(winAmount);
        bet.outcome = uint40(outcome);

        wagerwave.settleBet(player, amount, token, winnableAmount, winAmount > 0);
        
        emit BetSettled(betId, player, amount, coins, choice, outcome, winAmount, token);
    }

    /// @notice Calculates the potential win amount for a given bet.
    /// @param _token The address of the bet token.
    /// @param _amount The amount being wagered.
    /// @param _coins The number of coins to flip.
    /// @return uint256 The maximum winnable amount after deducting the house edge.
    function getWinnableAmount(address _token, uint256 _amount, uint256 _coins) internal view returns (uint256) {
        uint256 bettableAmount = _amount * (10000 - tokenInfo[_token].houseEdge) / 10000;
        return bettableAmount * 2 ** _coins;
    }

    /// @notice Returns the total number of bets placed.
    /// @return uint256 The length of the `bets` array, representing the total bets.
    function totalBets() external view returns (uint256) {
        return bets.length;
    }
}
