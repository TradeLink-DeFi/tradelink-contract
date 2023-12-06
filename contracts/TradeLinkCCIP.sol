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

contract TradeLinkCCIP is CCIPReceiver, OwnerIsCreator {
    // Custom errors to provide more descriptive revert messages.
    error NotEnoughBalance(uint256 currentBalance, uint256 calculatedFees); // Used to make sure contract has enough balance to cover the fees.
    error NothingToWithdraw(); // Used when trying to withdraw Ether but there's nothing to withdraw.
    error FailedToWithdrawEth(address owner, address target, uint256 value); // Used when the withdrawal of Ether fails.
    error DestinationChainNotAllowed(uint64 destinationChainSelector); // Used when the destination chain has not been allowlisted by the contract owner.
    error SourceChainNotAllowed(uint64 sourceChainSelector); // Used when the source chain has not been allowlisted by the contract owner.
    error SenderNotAllowed(address sender); // Used when the sender has not been allowlisted by the contract owner.

    event SendMessage(
        uint256 destinationChainSelector,
        address receiver,
        uint256 id,
        bytes32 messageId
    );

    struct Offer {
        address[] tokenIn;
        uint256[] tokenInAmount;
        bool[] isBridgeTokenIn;
        address[] tokenOut;
        uint256[] tokenOutAmount;
        bool[] isBridgeTokenOut;
        address[] nftIn;
        address[] nftOut;
        uint256[] nftInId;
        uint256[] nftOutId;
        address traderAddress;
        uint256 fee;
        address feeAddress;
    }

    struct FulfillOffer {
        uint256 offerId;
        uint64 destChainSelector;
        address destChainAddress;
        address[] tokenIn;
        uint256[] tokenInAmount;
        bool[] isBridgeTokenIn;
        address[] nftIn;
        uint256[] nftInId;
        address traderAddress;
    }

    struct MessagePayload {
        uint256 step;
        uint256 offerId;
        uint256 fulfillOfferId;
        FulfillOffer fulfillInfo;
    }

    uint256 runningOfferId;
    uint256 runningFulfillId;

    mapping(uint256 => Offer) public offerCollection;
    mapping(uint256 => FulfillOffer) public fulfillCollection;

    IRouterClient router;

    constructor(address _router) CCIPReceiver(_router) {
        router = IRouterClient(_router);
        runningOfferId = 0;
        runningFulfillId = 0;
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

            FulfillOffer memory fulfillInfo;
            Client.EVMTokenAmount[]
                memory tokenAmounts = new Client.EVMTokenAmount[](0);

            bytes memory _payload = encodedMessagePayload(
                MessagePayload({
                    step: 2,
                    offerId: dataStruct.offerId,
                    fulfillOfferId: dataStruct.fulfillOfferId,
                    fulfillInfo: fulfillInfo
                })
            );

            Client.EVM2AnyMessage memory evm2AnyMessage = _buildCCIPMessage(
                sender,
                _payload,
                tokenAmounts,
                offerCollection[dataStruct.offerId].feeAddress
            );

            bytes32 _messageId = router.ccipSend(
                sourceSelector,
                evm2AnyMessage
            );

            emit SendMessage(
                sourceSelector,
                sender,
                dataStruct.fulfillOfferId,
                _messageId
            );
        }

        if (dataStruct.step == 2) {
            emit SendMessage(
                sourceSelector,
                sender,
                dataStruct.fulfillOfferId,
                bytes32("")
            );
            transferToken(dataStruct.fulfillOfferId, false);
        }
    }

    function transferToken(uint256 id, bool isOffer) internal {
        if (isOffer) {
            address[] memory tokenIn = offerCollection[id].tokenIn;
            uint256[] memory amountIn = offerCollection[id].tokenInAmount;
            bool[] memory isBridgeTokenIn = offerCollection[id].isBridgeTokenIn;
            address recipent = offerCollection[id].traderAddress;

            for (uint i = 0; i < tokenIn.length; i++) {
                if (!isBridgeTokenIn[i]) {
                    IERC20(tokenIn[i]).transfer(recipent, amountIn[i]);
                }
            }
        } else {
            address[] memory tokenIn = fulfillCollection[id].tokenIn;
            uint256[] memory amountIn = fulfillCollection[id].tokenInAmount;
            bool[] memory isBridgeTokenIn = fulfillCollection[id]
                .isBridgeTokenIn;
            address recipent = fulfillCollection[id].traderAddress;

            for (uint i = 0; i < tokenIn.length; i++) {
                if (!isBridgeTokenIn[i]) {
                    IERC20(tokenIn[i]).transfer(recipent, amountIn[i]);
                }
            }
        }
    }

    function createOffer(bytes memory _createOffer) public returns (uint256) {
        runningOfferId += 1;

        Client.EVMTokenAmount[]
            memory tokenAmounts = new Client.EVMTokenAmount[](0);

        Offer memory _offer = decodeOffer(_createOffer);

        offerCollection[runningOfferId] = _offer;

        address _feeTokenAddress = _offer.feeAddress;
        LinkTokenInterface s_linkToken;
        uint256 fees = _offer.fee;

        if (address(_feeTokenAddress) != address(0)) {
            s_linkToken = LinkTokenInterface(_feeTokenAddress);
            if (fees > s_linkToken.balanceOf(msg.sender)) {
                revert NotEnoughBalance(
                    s_linkToken.balanceOf(msg.sender),
                    fees
                );
            } else {
                s_linkToken.transferFrom(msg.sender, address(this), fees);
                s_linkToken.approve(address(router), fees);
            }
        } else {
            if (fees > address(this).balance)
                revert NotEnoughBalance(address(this).balance, fees);
        }

        for (uint i = 0; i < _offer.tokenIn.length; i++) {
            IERC20(_offer.tokenIn[i]).transferFrom(
                msg.sender,
                address(this),
                _offer.tokenInAmount[i]
            );

            if (_offer.isBridgeTokenIn[i]) {
                tokenAmounts[0] = Client.EVMTokenAmount({
                    token: _offer.tokenIn[i],
                    amount: _offer.tokenInAmount[i]
                });
                IERC20(_offer.tokenIn[i]).approve(
                    address(router),
                    _offer.tokenInAmount[i]
                );
            }
        }

        for (uint i = 0; i < _offer.nftIn.length; i++) {
            IERC721(_offer.nftIn[i]).transferFrom(
                msg.sender,
                address(this),
                _offer.nftInId[i]
            );
        }

        return (runningOfferId);
    }

    function fulfillOffer(
        bytes memory _createFulfillOffer,
        uint64 _chainSelector,
        address _feeTokenAddress
    ) external returns (uint256 fullfillId, bytes32 messageId) {
        runningFulfillId += 1;

        bytes32 _messageId;
        LinkTokenInterface s_linkToken;
        Client.EVMTokenAmount[]
            memory tokenAmounts = new Client.EVMTokenAmount[](0);

        FulfillOffer memory _fulfillInfo = decodeFulfill(_createFulfillOffer);
        _fulfillInfo.destChainSelector = _chainSelector;

        MessagePayload memory messagePaylaod = MessagePayload({
            step: 1,
            offerId: _fulfillInfo.offerId,
            fulfillOfferId: runningFulfillId,
            fulfillInfo: _fulfillInfo
        });

        fulfillCollection[runningFulfillId] = _fulfillInfo;

        (
            uint256 fees,
            Client.EVM2AnyMessage memory evm2AnyMessage
        ) = getFeeFulfillOffer(messagePaylaod, _feeTokenAddress);

        // TODO : Check token fee
        if (address(_feeTokenAddress) != address(0)) {
            s_linkToken = LinkTokenInterface(_feeTokenAddress);
            if (fees > s_linkToken.balanceOf(msg.sender)) {
                revert NotEnoughBalance(
                    s_linkToken.balanceOf(msg.sender),
                    fees
                );
            } else {
                s_linkToken.transferFrom(msg.sender, address(this), fees);
                s_linkToken.approve(address(router), fees);
            }
        } else {
            if (fees > address(this).balance)
                revert NotEnoughBalance(address(this).balance, fees);
        }

        for (uint i = 0; i < _fulfillInfo.tokenIn.length; i++) {
            IERC20(_fulfillInfo.tokenIn[i]).transferFrom(
                msg.sender,
                address(this),
                _fulfillInfo.tokenInAmount[i]
            );

            if (_fulfillInfo.isBridgeTokenIn[i]) {
                tokenAmounts[0] = Client.EVMTokenAmount({
                    token: _fulfillInfo.tokenIn[i],
                    amount: _fulfillInfo.tokenInAmount[i]
                });
                IERC20(_fulfillInfo.tokenIn[i]).approve(
                    address(router),
                    _fulfillInfo.tokenInAmount[i]
                );
            }
        }

        for (uint i = 0; i < _fulfillInfo.nftIn.length; i++) {
            IERC721(_fulfillInfo.nftIn[i]).transferFrom(
                msg.sender,
                address(this),
                _fulfillInfo.nftInId[i]
            );
        }

        if (address(_feeTokenAddress) == address(0)) {
            _messageId = router.ccipSend{value: fees}(
                _fulfillInfo.destChainSelector,
                evm2AnyMessage
            );
        } else {
            _messageId = router.ccipSend(
                _fulfillInfo.destChainSelector,
                evm2AnyMessage
            );
        }

        return (runningFulfillId, _messageId);
    }

    function _buildCCIPMessage(
        address _receiver,
        bytes memory _payload,
        Client.EVMTokenAmount[] memory tokenAmounts,
        address _feeTokenAddress
    ) internal pure returns (Client.EVM2AnyMessage memory) {
        // Create an EVM2AnyMessage struct in memory with necessary information for sending a cross-chain message
        return
            Client.EVM2AnyMessage({
                receiver: abi.encode(_receiver), // ABI-encoded receiver address
                data: _payload, // ABI-encoded string
                tokenAmounts: tokenAmounts, // The amount and type of token being transferred
                extraArgs: Client._argsToBytes(
                    // Additional arguments, setting gas limit and non-strict sequencing mode
                    Client.EVMExtraArgsV1({gasLimit: 900_000, strict: false})
                ),
                // Set the feeToken to a feeTokenAddress, indicating specific asset will be used for fees
                feeToken: _feeTokenAddress
            });
    }

    function getFeeOffer(
        uint256 _offerId,
        uint256 _fulfillOfferId,
        uint64 _destChainSelector,
        address _destChainAddress,
        address _feeTokenAddress
    ) public view returns (uint256) {
        FulfillOffer memory _fulfillOffer;
        bytes memory _payload = encodedMessagePayload(
            MessagePayload({
                step: 2,
                offerId: _offerId,
                fulfillOfferId: _fulfillOfferId,
                fulfillInfo: _fulfillOffer
            })
        );

        Client.EVM2AnyMessage memory evm2AnyMessage = _buildCCIPMessage(
            _destChainAddress,
            _payload,
            new Client.EVMTokenAmount[](0),
            _feeTokenAddress
        );

        uint256 fees = router.getFee(_destChainSelector, evm2AnyMessage);

        return (fees);
    }

    function getFeeFulfillOffer(
        MessagePayload memory _messagePayload,
        address _feeTokenAddress
    ) public view returns (uint256, Client.EVM2AnyMessage memory) {
        bytes memory _payload = encodedMessagePayload(_messagePayload);

        FulfillOffer memory _fulfillOffer = _messagePayload.fulfillInfo;

        Client.EVM2AnyMessage memory evm2AnyMessage = _buildCCIPMessage(
            _fulfillOffer.destChainAddress,
            _payload,
            new Client.EVMTokenAmount[](0),
            _feeTokenAddress
        );

        uint256 fees = router.getFee(
            _fulfillOffer.destChainSelector,
            evm2AnyMessage
        );

        return (fees, evm2AnyMessage);
    }

    // TODO : Part of encode & decode
    function decodeOffer(
        bytes memory encodedData
    ) public pure returns (Offer memory decodedData) {
        Offer memory _decodedData = abi.decode(encodedData, (Offer));
        return _decodedData;
    }

    function decodeFulfill(
        bytes memory encodedData
    ) public pure returns (FulfillOffer memory decoded) {
        FulfillOffer memory decodedFulfillOffer = abi.decode(
            encodedData,
            (FulfillOffer)
        );

        return decodedFulfillOffer;
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

    // TODO : withdraw native
    function withdraw(address _beneficiary) public onlyOwner {
        // Retrieve the balance of this contract
        uint256 amount = address(this).balance;

        // Revert if there is nothing to withdraw
        if (amount == 0) revert NothingToWithdraw();

        // Attempt to send the funds, capturing the success status and discarding any return data
        (bool sent, ) = _beneficiary.call{value: amount}("");

        // Revert if the send failed, with information about the attempted transfer
        if (!sent) revert FailedToWithdrawEth(msg.sender, _beneficiary, amount);
    }

    // TODO : withdraw token
    function withdrawToken(
        address _beneficiary,
        address _token
    ) public onlyOwner {
        // Retrieve the balance of this contract
        uint256 amount = IERC20(_token).balanceOf(address(this));

        // Revert if there is nothing to withdraw
        if (amount == 0) revert NothingToWithdraw();

        IERC20(_token).transfer(_beneficiary, amount);
    }
}
