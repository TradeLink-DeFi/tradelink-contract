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

contract TradeLinkCCIPV1 is CCIPReceiver, OwnerIsCreator {
    // Custom errors to provide more descriptive revert messages.
    error NotEnoughBalance(uint256 currentBalance, uint256 calculatedFees); // Used to make sure contract has enough balance to cover the fees.
    error NothingToWithdraw(); // Used when trying to withdraw Ether but there's nothing to withdraw.
    error FailedToWithdrawEth(address owner, address target, uint256 value); // Used when the withdrawal of Ether fails.

    event Success(
        uint256 offerId,
        uint256 fulfillId,
        uint64 sourceChain,
        uint64 destChain,
        address userOffer,
        address userFulfill
    );

    struct Offer {
        address[] tokenIn;
        uint256[] tokenInAmount;
        address[] nftIn;
        uint256[] nftInId;
        uint64 destSelectorOut;
        address[] tokenOut;
        uint256[] tokenOutAmount;
        address[] nftOut;
        uint256[] nftOutId;
        address ownerOfferAddress;
        address traderOfferAddress;
        uint256 deadLine;
        uint256 fee;
        address feeAddress;
        bool isSuccess;
    }

    struct FulfillOffer {
        uint256 offerId;
        uint64 destChainSelector;
        address destChainAddress;
        address[] tokenIn;
        uint256[] tokenInAmount;
        address[] nftIn;
        uint256[] nftInId;
        address feeAddress;
        address ownerFulfillAddress;
        address traderFulfillAddress;
        bool isBridge;
        bool isSuccess;
    }

    uint256 runningOfferId;
    uint256 runningFulfillId;
    uint64 public sourceChainSelector;
    uint256 public feePlatform;

    mapping(uint256 => Offer) public offerCollection;
    mapping(uint256 => FulfillOffer) public fulfillCollection;

    IRouterClient router;

    struct MessagePayload {
        uint256 step;
        uint256 offerId;
        uint256 fulfillOfferId;
        FulfillOffer fulfillInfo;
    }

    constructor(
        address _router,
        uint256 _sourceSelector
    ) CCIPReceiver(_router) {
        router = IRouterClient(_router);
        sourceChainSelector = uint64(_sourceSelector);
        runningOfferId = 0;
        runningFulfillId = 0;
        feePlatform = 5;
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
            if (
                !offerCollection[dataStruct.offerId].isSuccess &&
                !(offerCollection[dataStruct.offerId].deadLine <
                    block.timestamp) &&
                validateOfferOutAndFulfillIn(
                    offerCollection[dataStruct.offerId],
                    dataStruct.fulfillInfo
                )
            ) {
                transferTokenAndNFT(dataStruct.offerId, true);

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

                offerCollection[dataStruct.offerId].isSuccess = true;

                router.ccipSend(sourceSelector, evm2AnyMessage);
            }
        }

        if (dataStruct.step == 2) {
            transferTokenAndNFT(dataStruct.fulfillOfferId, false);
            fulfillCollection[dataStruct.fulfillOfferId].isSuccess = true;
            emit Success(
                dataStruct.offerId,
                dataStruct.fulfillOfferId,
                sourceChainSelector,
                sourceSelector,
                dataStruct.fulfillInfo.traderFulfillAddress,
                dataStruct.fulfillInfo.ownerFulfillAddress
            );
        }
    }

    function createOffer(bytes memory _createOffer) external returns (uint256) {
        runningOfferId += 1;

        Offer memory _offer = decodeOffer(_createOffer);
        _offer.isSuccess = false;
        _offer.deadLine = block.timestamp + 3 hours;
        offerCollection[runningOfferId] = _offer;

        address _feeTokenAddress = _offer.feeAddress;

        uint256 fees = _offer.fee;

        // TODO: Check token fee
        checkFee(_feeTokenAddress, fees);

        // TODO: transferFron token and nft
        transferFromToThis(
            _offer.tokenIn,
            _offer.tokenInAmount,
            _offer.nftIn,
            _offer.nftInId
        );

        return (runningOfferId);
    }

    function fulfillOffer(
        bytes memory _createFulfillOffer
    ) external returns (uint256 fullfillId, bytes32 messageId) {
        runningFulfillId += 1;

        bytes32 _messageId;
        Client.EVMTokenAmount[]
            memory tokenAmounts = new Client.EVMTokenAmount[](0);

        FulfillOffer memory _fulfillInfo = decodeFulfill(_createFulfillOffer);
        address _feeTokenAddress = _fulfillInfo.feeAddress;

        bool isNative = address(_feeTokenAddress) == address(0);

        fulfillCollection[runningFulfillId] = _fulfillInfo;

        // TODO: check fulfill destChainSelector = sourceChainSelector
        if (!_fulfillInfo.isBridge) {
            address fulfillTrader = offerCollection[_fulfillInfo.offerId]
                .traderOfferAddress;
            require(
                msg.sender == fulfillTrader,
                "Trader address is incorrect!"
            );

            // TODO: offer transfer to fulfill trader
            transferTokenAndNFT(_fulfillInfo.offerId, true);

            // TODO: fulfill transfer to offer trader
            transferFromToTrader(
                _fulfillInfo.tokenIn,
                _fulfillInfo.tokenInAmount,
                _fulfillInfo.nftIn,
                _fulfillInfo.nftInId,
                _fulfillInfo.traderFulfillAddress
            );

            offerCollection[_fulfillInfo.offerId].isSuccess = true;
        } else {
            MessagePayload memory messagePaylaod = MessagePayload({
                step: 1,
                offerId: _fulfillInfo.offerId,
                fulfillOfferId: runningFulfillId,
                fulfillInfo: _fulfillInfo
            });

            bytes memory _payload = encodedMessagePayload(messagePaylaod);

            Client.EVM2AnyMessage memory evm2AnyMessage = _buildCCIPMessage(
                _fulfillInfo.destChainAddress,
                _payload,
                tokenAmounts,
                _feeTokenAddress
            );

            uint256 fees = _getFeeFulfillOffer(messagePaylaod);

            // TODO: Check token fee
            checkFee(_feeTokenAddress, fees);

            transferFromToThis(
                _fulfillInfo.tokenIn,
                _fulfillInfo.tokenInAmount,
                _fulfillInfo.nftIn,
                _fulfillInfo.nftInId
            );

            _messageId = sendCCIPMessage(
                isNative,
                _fulfillInfo.destChainSelector,
                fees,
                evm2AnyMessage
            );
        }

        return (runningFulfillId, _messageId);
    }

    function transferTokenAndNFT(uint256 id, bool isOffer) internal {
        address[] memory tokenIn = isOffer
            ? offerCollection[id].tokenIn
            : fulfillCollection[id].tokenIn;

        uint256[] memory amountIn = isOffer
            ? offerCollection[id].tokenInAmount
            : fulfillCollection[id].tokenInAmount;

        address recipent = isOffer
            ? offerCollection[id].traderOfferAddress
            : fulfillCollection[id].traderFulfillAddress;

        address[] memory nftIn = isOffer
            ? offerCollection[id].nftIn
            : fulfillCollection[id].nftIn;

        uint256[] memory nftInId = isOffer
            ? offerCollection[id].nftInId
            : fulfillCollection[id].nftInId;

        for (uint i = 0; i < tokenIn.length; i++) {
            IERC20(tokenIn[i]).transfer(recipent, amountIn[i]);
        }
        for (uint i = 0; i < nftIn.length; i++) {
            IERC721(nftIn[i]).transferFrom(address(this), recipent, nftInId[i]);
        }
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

    function transferFromToTrader(
        address[] memory tokens,
        uint256[] memory tokensAmount,
        address[] memory nfts,
        uint256[] memory nftsId,
        address trader
    ) internal {
        for (uint i = 0; i < tokens.length; i++) {
            IERC20(tokens[i]).transferFrom(
                msg.sender,
                address(trader),
                tokensAmount[i]
            );
        }

        for (uint i = 0; i < nfts.length; i++) {
            IERC721(nfts[i]).transferFrom(
                msg.sender,
                address(trader),
                nftsId[i]
            );
        }
    }

    function sendCCIPMessage(
        bool _isNative,
        uint64 _destChainSelector,
        uint256 _fees,
        Client.EVM2AnyMessage memory _evm2AnyMessage
    ) internal returns (bytes32 messageId) {
        bytes32 _messageId;

        if (_isNative) {
            _messageId = router.ccipSend{value: _fees}(
                _destChainSelector,
                _evm2AnyMessage
            );
        } else {
            _messageId = router.ccipSend(_destChainSelector, _evm2AnyMessage);
        }

        return messageId;
    }

    function checkChianSelector(
        uint64[] memory _destChainSelector
    ) internal view returns (bool isInChain) {
        bool _isInChain = true;
        for (uint i = 0; i < _destChainSelector.length; i++) {
            if (_isInChain) {
                _isInChain = _destChainSelector[i] == sourceChainSelector
                    ? true
                    : false;
            }
        }
        return _isInChain;
    }

    function validateOfferOutAndFulfillIn(
        Offer memory _offer,
        FulfillOffer memory _fulfillOffer
    ) internal pure returns (bool) {
        bool isOk;
        if (_offer.tokenOut.length != _fulfillOffer.tokenIn.length)
            return false;
        if (_offer.nftOut.length != _fulfillOffer.nftIn.length) return false;

        for (uint i = 0; i < _offer.tokenOut.length; i++) {
            isOk =
                _fulfillOffer.tokenIn[i] == _offer.tokenOut[i] &&
                _fulfillOffer.tokenInAmount[i] == _offer.tokenOutAmount[i];
        }

        for (uint i = 0; i < _offer.nftOut.length; i++) {
            isOk =
                _fulfillOffer.nftIn[i] == _offer.nftOut[i] &&
                _fulfillOffer.nftInId[i] == _offer.nftOutId[i];
        }

        return isOk;
    }

    function checkFee(address _feeTokenAddress, uint256 fees) internal {
        if (address(_feeTokenAddress) != address(0)) {
            LinkTokenInterface s_linkToken = LinkTokenInterface(
                _feeTokenAddress
            );
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
    }

    function transferFromToThis(
        address[] memory tokens,
        uint256[] memory tokensAmount,
        address[] memory nfts,
        uint256[] memory nftsId
    ) internal {
        for (uint i = 0; i < tokens.length; i++) {
            IERC20(tokens[i]).transferFrom(
                msg.sender,
                address(this),
                tokensAmount[i]
            );
        }

        for (uint i = 0; i < nfts.length; i++) {
            IERC721(nfts[i]).transferFrom(msg.sender, address(this), nftsId[i]);
        }
    }

    function getFeeOffer(
        uint256 _fulfillOfferId,
        uint64 _destChainSelector,
        address _destChainAddress,
        address _feeTokenAddress,
        address _ccipAddress,
        uint256 _ccipAmount
    ) external view returns (uint256) {
        FulfillOffer memory _fulfillOffer;
        bytes memory _payload = encodedMessagePayload(
            MessagePayload({
                step: 2,
                offerId: 0,
                fulfillOfferId: _fulfillOfferId,
                fulfillInfo: _fulfillOffer
            })
        );

        Client.EVMTokenAmount[]
            memory tokenAmounts = new Client.EVMTokenAmount[](0);

        if (_ccipAddress != address(0) && _ccipAmount > uint256(0)) {
            tokenAmounts[0] = Client.EVMTokenAmount({
                token: _ccipAddress,
                amount: _ccipAmount
            });
        }

        Client.EVM2AnyMessage memory evm2AnyMessage = _buildCCIPMessage(
            _destChainAddress,
            _payload,
            tokenAmounts,
            _feeTokenAddress
        );

        uint256 fees = router.getFee(_destChainSelector, evm2AnyMessage);
        fees = ((feePlatform * fees) / 100) + fees;

        return (fees);
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

    function getFeeFulfillOffer(
        MessagePayload memory _messagePayload
    ) external view returns (uint256) {
        return _getFeeFulfillOffer(_messagePayload);
    }

    function _getFeeFulfillOffer(
        MessagePayload memory _messagePayload
    ) internal view returns (uint256) {
        bytes memory _payload = encodedMessagePayload(_messagePayload);

        FulfillOffer memory _fulfillOffer = _messagePayload.fulfillInfo;

        Client.EVM2AnyMessage memory evm2AnyMessage = _buildCCIPMessage(
            _fulfillOffer.destChainAddress,
            _payload,
            new Client.EVMTokenAmount[](0),
            _fulfillOffer.feeAddress
        );

        uint256 fees = router.getFee(
            _fulfillOffer.destChainSelector,
            evm2AnyMessage
        );

        fees = ((feePlatform * fees) / 100) + fees;

        return (fees);
    }

    // TODO: Part of encode & decode
    function decodeOffer(
        bytes memory encodedData
    ) public pure returns (Offer memory decodedData) {
        Offer memory _decodedData = abi.decode(encodedData, (Offer));
        return _decodedData;
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

    // TODO: withdraw native
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

    // TODO: withdraw token
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

    // TODO: withdraw token
    function withdrawNFT(
        address _nft,
        address _beneficiary,
        uint256 _id
    ) public onlyOwner {
        // Retrieve the balance of this contract
        IERC721(_nft).transferFrom(address(0), _beneficiary, _id);
    }

    function setFee(uint256 fee) public onlyOwner {
        feePlatform = fee;
    }
}
