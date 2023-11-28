// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import {IRouterClient} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {OwnerIsCreator} from "@chainlink/contracts-ccip/src/v0.8/shared/access/OwnerIsCreator.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {CCIPReceiver} from "@chainlink/contracts-ccip/src/v0.8/ccip/applications/CCIPReceiver.sol";
import {IERC20} from "@chainlink/contracts-ccip/src/v0.8/vendor/openzeppelin-solidity/v4.8.0/token/ERC20/IERC20.sol";
import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol";

import {IERC721} from "./interfaces/IERC721.sol";

contract TradeLink is CCIPReceiver, OwnerIsCreator {
    IRouterClient private s_router;
    LinkTokenInterface private s_linkToken;

    struct TokenIn {
        address tokenIn;
        uint256 tokenInAmount;
    }

    struct TokenOut {
        address tokenOut;
        uint256 tokenOutAmount;
    }

    struct NFTIn {
        address nftIn;
        uint256 nftInId;
    }

    struct NFTOut {
        address nftOut;
        uint256 nftOutId;
    }

    struct Offer {
        address traderAddress;
        uint256 destChain;
        TokenIn[] tokenIn;
        TokenOut[] tokenOut;
        NFTIn[] nftIn;
        NFTOut[] nftOut;
    }

    mapping(uint256 => Offer) offerCollection;
    uint256 runningNumber;

    constructor(address _router, address _link) CCIPReceiver(_router) {
        s_router = IRouterClient(_router);
        s_linkToken = LinkTokenInterface(_link);
        runningNumber = 0;
    }

    function _ccipReceive(
        Client.Any2EVMMessage memory any2EvmMessage
    ) internal override {}

    function createOffer(
        uint256 _destChain,
        TokenIn[] memory _tokenIn,
        TokenOut[] memory _tokenOut,
        NFTIn[] memory _nftIn,
        NFTOut[] memory _nftOut,
        address _traderAddress
    ) external returns (uint256 offerNumber) {
        runningNumber += 1;

        offerCollection[runningNumber].tokenIn = _tokenIn;
        offerCollection[runningNumber].tokenOut = _tokenOut;
        offerCollection[runningNumber].nftIn = _nftIn;
        offerCollection[runningNumber].nftOut = _nftOut;
        offerCollection[runningNumber].destChain = _destChain;
        offerCollection[runningNumber].traderAddress = _traderAddress;

        for (uint i = 0; i < _tokenIn.length; i++) {
            address tkIn = _tokenIn[i].tokenIn;
            uint256 amount = _tokenIn[i].tokenInAmount;
            IERC20 token = IERC20(tkIn);

            token.approve(address(s_router), amount);
            token.transferFrom(msg.sender, address(this), amount);
        }

        for (uint i = 0; i < _nftIn.length; i++) {
            address nftIn = _nftIn[i].nftIn;
            uint256 nftInId = _nftIn[i].nftInId;

            IERC721 nft = IERC721(nftIn);
            nft.approve(address(s_router), nftInId);
            nft.transferFrom(msg.sender, address(s_router), nftInId);
        }

        return (runningNumber);
    }

    function sendMessage() internal {}

    function fullFillOffer(
        uint256 offerId,
        uint256 destChain,
        TokenIn[] memory _tokenIn,
        NFTIn memory _nftIn
    ) public {}
}
