// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {IRouterClient} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {OwnerIsCreator} from "@chainlink/contracts-ccip/src/v0.8/shared/access/OwnerIsCreator.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {CCIPReceiver} from "@chainlink/contracts-ccip/src/v0.8/ccip/applications/CCIPReceiver.sol";
import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol";

import "hardhat/console.sol";

import {IERC721} from "./interfaces/IERC721.sol";
import {IERC20} from "./interfaces/IERC20.sol";

contract TradeLink is CCIPReceiver, OwnerIsCreator {
    error NotEnoughBalance(uint256 currentBalance, uint256 calculatedFees);

    event SendMessage(uint256 destinationChainSelector, address receiver);
    event CheckLink(uint256 userLink);
    event CheckChainSelectore(uint256 selector);

    IRouterClient private s_router;
    LinkTokenInterface private s_linkToken;

    receive() external payable {}

    constructor(address _router, address _link) CCIPReceiver(_router) {
        s_router = IRouterClient(_router);
        s_linkToken = LinkTokenInterface(_link);
        runningOfferId = 0;
        runningFulfillId = 0;
    }

    struct Offer {
        address[] tokenIn;
        address[] tokenOut;
        uint256[] tokenInAmount;
        uint256[] tokenOutAmount;
        address[] nftIn;
        address[] nftOut;
        uint256[] nftInId;
        uint256[] nftOutId;
        address traderAddress;
        uint256 deadlineAt;
        bool isAvailable;
    }

    struct FulfillOffer {
        uint256 offerId;
        uint64 destChainSelector;
        address destChainAddress;
        address[] tokenIn;
        uint256[] tokenInAmount;
        address[] nftIn;
        uint256[] nftInId;
        address traderAddress;
    }

    uint256 runningOfferId;
    uint256 runningFulfillId;

    mapping(uint256 => Offer) public offerCollection;
    mapping(uint256 => FulfillOffer) public fulfillCollection;

    mapping(address => uint256[]) public userOfferIds;

    struct MessagePayload {
        uint256 step;
        uint256 offerId;
        uint256 fulfillOfferId;
        FulfillOffer fulfillInfo;
    }

    function _ccipReceive(
        Client.Any2EVMMessage memory any2EvmMessage
    ) internal override {
        address sender = abi.decode(any2EvmMessage.sender, (address));
        uint64 sourceSelector = any2EvmMessage.sourceChainSelector; // fetch the source chain identifier (aka selector)

        MessagePayload memory dataStruct = decodeMessagePayload(
            any2EvmMessage.data
        );

        if (dataStruct.step == 1) {
            transferToken(dataStruct.offerId, true);

            bytes memory _payload = encodedMessagePayload(
                MessagePayload({
                    step: 2,
                    offerId: dataStruct.offerId,
                    fulfillOfferId: dataStruct.fulfillOfferId,
                    fulfillInfo: dataStruct.fulfillInfo
                })
            );

            sendMessage(sender, sourceSelector, _payload);
        }

        if (dataStruct.step == 2) {
            transferToken(dataStruct.fulfillOfferId, false);
        }
    }

    function transferToken(uint256 id, bool isOffer) internal {
        if (isOffer) {
            address[] memory tokenIn = offerCollection[id].tokenIn;
            uint256[] memory amountIn = offerCollection[id].tokenInAmount;
            address recipent = offerCollection[id].traderAddress;

            for (uint i = 0; i < tokenIn.length; i++) {
                IERC20(tokenIn[i]).transfer(recipent, amountIn[i]);
            }
        } else {
            address[] memory tokenIn = fulfillCollection[id].tokenIn;
            uint256[] memory amountIn = fulfillCollection[id].tokenInAmount;
            address recipent = fulfillCollection[id].traderAddress;

            for (uint i = 0; i < tokenIn.length; i++) {
                IERC20(tokenIn[i]).transfer(recipent, amountIn[i]);
            }
        }
    }

    function createOffer(bytes memory _createOffer) public returns (uint256) {
        runningOfferId += 1;

        Offer memory _offer = decodeCreateOffer(_createOffer);
        _offer.deadlineAt = block.timestamp + 3 hours;
        _offer.isAvailable = true;

        offerCollection[runningOfferId] = _offer;

        for (uint i = 0; i < _offer.tokenIn.length; i++) {
            IERC20(_offer.tokenIn[i]).transferFrom(
                msg.sender,
                address(this),
                _offer.tokenInAmount[i]
            );
        }

        for (uint i = 0; i < _offer.nftIn.length; i++) {
            IERC721(_offer.nftIn[i]).transferFrom(
                msg.sender,
                address(this),
                _offer.nftInId[i]
            );
        }

        userOfferIds[msg.sender].push(runningOfferId);

        return (runningOfferId);
    }

    // 1. start process
    function fulfillOffer(
        bytes memory _createFulfillOffer,
        uint64 chainSelector
    ) external returns (uint256 fullfillId) {
        runningFulfillId += 1;

        FulfillOffer memory _fulfillInfo = decodeFulfillOffer(
            _createFulfillOffer,
            chainSelector
        );

        _fulfillInfo.destChainSelector = chainSelector;

        bytes memory _payload = encodedMessagePayload(
            MessagePayload({
                step: 1,
                offerId: _fulfillInfo.offerId,
                fulfillOfferId: runningFulfillId,
                fulfillInfo: _fulfillInfo
            })
        );

        uint256 fees = getFee(
            _fulfillInfo.destChainAddress,
            _fulfillInfo.destChainSelector,
            _payload
        );

        if (fees > s_linkToken.balanceOf(msg.sender))
            revert NotEnoughBalance(s_linkToken.balanceOf(msg.sender), fees);

        emit CheckLink(s_linkToken.balanceOf(msg.sender));

        s_linkToken.transferFrom(msg.sender, address(this), fees);

        for (uint i = 0; i < _fulfillInfo.tokenIn.length; i++) {
            IERC20(_fulfillInfo.tokenIn[i]).transferFrom(
                msg.sender,
                address(this),
                _fulfillInfo.tokenInAmount[i]
            );
        }

        for (uint i = 0; i < _fulfillInfo.nftIn.length; i++) {
            IERC721(_fulfillInfo.nftIn[i]).transferFrom(
                msg.sender,
                address(this),
                _fulfillInfo.nftInId[i]
            );
        }

        sendMessage(
            _fulfillInfo.destChainAddress,
            _fulfillInfo.destChainSelector,
            _payload
        );

        return (runningFulfillId);
    }

    function getMessage(
        address receiver,
        bytes memory _payload
    ) internal view returns (Client.EVM2AnyMessage memory _evm2AnyMessage) {
        Client.EVM2AnyMessage memory evm2AnyMessage = Client.EVM2AnyMessage({
            receiver: abi.encode(receiver),
            data: _payload,
            tokenAmounts: new Client.EVMTokenAmount[](0),
            extraArgs: Client._argsToBytes(
                Client.EVMExtraArgsV1({gasLimit: 900_000, strict: false})
            ),
            feeToken: address(s_linkToken)
        });
        return (evm2AnyMessage);
    }

    function sendMessage(
        address receiver,
        uint64 chainSelector,
        bytes memory _payload
    ) internal {
        Client.EVM2AnyMessage memory evm2AnyMessage = getMessage(
            receiver,
            _payload
        );
        uint256 fees = s_router.getFee(chainSelector, evm2AnyMessage);

        if (fees > s_linkToken.balanceOf(address(this)))
            revert NotEnoughBalance(s_linkToken.balanceOf(address(this)), fees);

        s_linkToken.approve(address(s_router), fees);

        // s_router.ccipSend(chainSelector, evm2AnyMessage);
    }

    function getOfferId() public view returns (uint256[] memory) {
        return userOfferIds[msg.sender];
    }

    function offerProcess(uint256 id) internal {
        Offer memory _offer = offerCollection[id];

        if (_offer.tokenIn.length > 0) {
            for (uint i = 0; i < _offer.tokenIn.length; i++) {
                IERC20 token = IERC20(_offer.tokenIn[i]);
                token.transfer(_offer.traderAddress, _offer.tokenInAmount[i]);
            }
        }
    }

    function getFee(
        address receiver,
        uint64 chainSelector,
        bytes memory _payload
    ) public view returns (uint256) {
        Client.EVM2AnyMessage memory evm2AnyMessage = Client.EVM2AnyMessage({
            receiver: abi.encode(receiver),
            data: _payload,
            tokenAmounts: new Client.EVMTokenAmount[](0),
            extraArgs: Client._argsToBytes(
                Client.EVMExtraArgsV1({gasLimit: 900_000, strict: false})
            ),
            feeToken: address(s_linkToken)
        });

        uint256 fees = s_router.getFee(chainSelector, evm2AnyMessage);

        return (fees);
    }

    function encodedMessagePayload(
        MessagePayload memory _messagePayload
    ) public pure returns (bytes memory) {
        bytes memory encodedData = abi.encode(_messagePayload);
        return encodedData;
    }

    function decodeMessagePayload(
        bytes memory encodedData
    ) public pure returns (MessagePayload memory decoded) {
        MessagePayload memory decodedMessagePayload = abi.decode(
            encodedData,
            (MessagePayload)
        );

        return decodedMessagePayload;
    }

    function decodeCreateOffer(
        bytes memory encodedData
    ) public pure returns (Offer memory decodedData) {
        Offer memory _decodedData = abi.decode(encodedData, (Offer));
        return _decodedData;
    }

    function decodeFulfillOffer(
        bytes memory encodedData,
        uint64 chainSelector
    ) public pure returns (FulfillOffer memory decoded) {
        FulfillOffer memory decodedFulfillOffer = abi.decode(
            encodedData,
            (FulfillOffer)
        );
        decodedFulfillOffer.destChainSelector = chainSelector;
        return decodedFulfillOffer;
    }

    function withdrawToken(
        address _beneficiary,
        address _token
    ) public onlyOwner {
        // Retrieve the balance of this contract
        uint256 amount = IERC20(_token).balanceOf(address(this));

        IERC20(_token).transfer(_beneficiary, amount);
    }
}

// sepolia 0x649dA825a2796D2ea258Df1d6B1A20D8dFAD0546
// mumbai 0x241c7cDAf52A16C5F8FB0328c662461fd8D71672
