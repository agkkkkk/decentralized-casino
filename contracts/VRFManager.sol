// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
import {IVRFCoordinatorV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/interfaces/IVRFCoordinatorV2Plus.sol";

import "./interface/IWagerWave.sol";
import "./interface/IGame.sol";

contract VRFManager is VRFConsumerBaseV2Plus {
    error InvalidVRFRequest();

    IWagerWave wagerwave;

    uint256 s_subscriptionId;
    address vrfCoordinator;
    bytes32 s_keyHash;
    uint32 callbackGasLimit = 300000;
    uint16 requestConfirmations = 3;
    uint32 numWords = 1;

    /// @notice Mapping from request ID to bet ID
    mapping(uint256 => uint256) private requestIdToBetId;

    /// @notice Mapping from request ID to bet ID
    mapping(uint256 => address) private requestIdToGame;

    constructor(uint256 _subscriptionId, address _coordinatorVRF, bytes32 _keyHash, address _wagerwave)
        VRFConsumerBaseV2Plus(_coordinatorVRF)
    {
        s_subscriptionId = _subscriptionId;
        vrfCoordinator = _coordinatorVRF;
        s_keyHash = _keyHash;

        wagerwave = IWagerWave(_wagerwave);
    }

    /// @notice Requests a random number from Chainlink VRF.
    /// @dev The request ID is mapped to the caller game contract for settlement upon VRF fulfillment.
    /// @return requestId The unique ID of the VRF request.
    function requestRandomNumber() external returns (uint256 requestId) {
        if (!(wagerwave.isGameSupported(msg.sender))) {
            revert InvalidVRFRequest();
        }

        requestId = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: s_keyHash,
                subId: s_subscriptionId,
                requestConfirmations: requestConfirmations,
                callbackGasLimit: callbackGasLimit,
                numWords: numWords,
                // Set nativePayment to true to pay for VRF requests with Sepolia ETH instead of LINK
                extraArgs: VRFV2PlusClient._argsToBytes(VRFV2PlusClient.ExtraArgsV1({nativePayment: false}))
            })
        );

        requestIdToGame[requestId] = msg.sender;
    }

    function fulfillRandomWords(uint256 requestId, uint256[] calldata randomWords) internal override {
        address game = requestIdToGame[requestId];

        IGame(game).settleBet(requestId, randomWords);

        delete requestIdToGame[requestId];
    }

    /// @notice Updates the subscription ID for VRF requests.
    /// @param _subscriptionId New subscription ID
    function setSubscriptionId(uint64 _subscriptionId) external onlyOwner {
        s_subscriptionId = _subscriptionId;
    }

    /// @notice Updates the key hash for VRF requests.
    /// @param _keyHash New key hash
    function setKeyHash(bytes32 _keyHash) external onlyOwner {
        s_keyHash = _keyHash;
    }

    /// @notice Updates the callback gas limit for VRF responses.
    /// @param _callbackGasLimit New callback gas limit
    function setCallbackGasLimit(uint32 _callbackGasLimit) external onlyOwner {
        callbackGasLimit = _callbackGasLimit;
    }
}
