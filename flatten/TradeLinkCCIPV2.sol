// Sources flattened with hardhat v2.19.1 https://hardhat.org

// SPDX-License-Identifier: MIT AND UNLICENSED

// File @chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol@v0.7.6

// Original license: SPDX_License_Identifier: MIT
pragma solidity ^0.8.0;

// End consumer library.
library Client {
  struct EVMTokenAmount {
    address token; // token address on the local chain.
    uint256 amount; // Amount of tokens.
  }

  struct Any2EVMMessage {
    bytes32 messageId; // MessageId corresponding to ccipSend on source.
    uint64 sourceChainSelector; // Source chain selector.
    bytes sender; // abi.decode(sender) if coming from an EVM chain.
    bytes data; // payload sent in original message.
    EVMTokenAmount[] destTokenAmounts; // Tokens and their amounts in their destination chain representation.
  }

  // If extraArgs is empty bytes, the default is 200k gas limit and strict = false.
  struct EVM2AnyMessage {
    bytes receiver; // abi.encode(receiver address) for dest EVM chains
    bytes data; // Data payload
    EVMTokenAmount[] tokenAmounts; // Token transfers
    address feeToken; // Address of feeToken. address(0) means you will send msg.value.
    bytes extraArgs; // Populate this with _argsToBytes(EVMExtraArgsV1)
  }

  // extraArgs will evolve to support new features
  // bytes4(keccak256("CCIP EVMExtraArgsV1"));
  bytes4 public constant EVM_EXTRA_ARGS_V1_TAG = 0x97a657c9;
  struct EVMExtraArgsV1 {
    uint256 gasLimit; // ATTENTION!!! MAX GAS LIMIT 4M FOR BETA TESTING
    bool strict; // See strict sequencing details below.
  }

  function _argsToBytes(EVMExtraArgsV1 memory extraArgs) internal pure returns (bytes memory bts) {
    return abi.encodeWithSelector(EVM_EXTRA_ARGS_V1_TAG, extraArgs);
  }
}


// File @chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IAny2EVMMessageReceiver.sol@v0.7.6

// Original license: SPDX_License_Identifier: MIT
pragma solidity ^0.8.0;

/// @notice Application contracts that intend to receive messages from
/// the router should implement this interface.
interface IAny2EVMMessageReceiver {
  /// @notice Called by the Router to deliver a message.
  /// If this reverts, any token transfers also revert. The message
  /// will move to a FAILED state and become available for manual execution.
  /// @param message CCIP Message
  /// @dev Note ensure you check the msg.sender is the OffRampRouter
  function ccipReceive(Client.Any2EVMMessage calldata message) external;
}


// File @chainlink/contracts-ccip/src/v0.8/vendor/openzeppelin-solidity/v4.8.0/utils/introspection/IERC165.sol@v0.7.6

// Original license: SPDX_License_Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/introspection/IERC165.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC165 standard, as defined in the
 * https://eips.ethereum.org/EIPS/eip-165[EIP].
 *
 * Implementers can declare support of contract interfaces, which can then be
 * queried by others ({ERC165Checker}).
 *
 * For an implementation, see {ERC165}.
 */
interface IERC165 {
  /**
    * @dev Returns true if this contract implements the interface defined by
    * `interfaceId`. See the corresponding
    * https://eips.ethereum.org/EIPS/eip-165#how-interfaces-are-identified[EIP section]
    * to learn more about how these ids are created.
    *
    * This function call must use less than 30 000 gas.
    */
  function supportsInterface(bytes4 interfaceId) external view returns (bool);
}


// File @chainlink/contracts-ccip/src/v0.8/ccip/applications/CCIPReceiver.sol@v0.7.6

// Original license: SPDX_License_Identifier: MIT
pragma solidity ^0.8.0;

/// @title CCIPReceiver - Base contract for CCIP applications that can receive messages.
abstract contract CCIPReceiver is IAny2EVMMessageReceiver, IERC165 {
  address internal immutable i_router;

  constructor(address router) {
    if (router == address(0)) revert InvalidRouter(address(0));
    i_router = router;
  }

  /// @notice IERC165 supports an interfaceId
  /// @param interfaceId The interfaceId to check
  /// @return true if the interfaceId is supported
  function supportsInterface(bytes4 interfaceId) public pure override returns (bool) {
    return interfaceId == type(IAny2EVMMessageReceiver).interfaceId || interfaceId == type(IERC165).interfaceId;
  }

  /// @inheritdoc IAny2EVMMessageReceiver
  function ccipReceive(Client.Any2EVMMessage calldata message) external virtual override onlyRouter {
    _ccipReceive(message);
  }

  /// @notice Override this function in your implementation.
  /// @param message Any2EVMMessage
  function _ccipReceive(Client.Any2EVMMessage memory message) internal virtual;

  /////////////////////////////////////////////////////////////////////
  // Plumbing
  /////////////////////////////////////////////////////////////////////

  /// @notice Return the current router
  /// @return i_router address
  function getRouter() public view returns (address) {
    return address(i_router);
  }

  error InvalidRouter(address router);

  /// @dev only calls from the set router are accepted.
  modifier onlyRouter() {
    if (msg.sender != address(i_router)) revert InvalidRouter(msg.sender);
    _;
  }
}


// File @chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol@v0.7.6

// Original license: SPDX_License_Identifier: MIT
pragma solidity ^0.8.0;

interface IRouterClient {
  error UnsupportedDestinationChain(uint64 destChainSelector);
  error InsufficientFeeTokenAmount();
  error InvalidMsgValue();

  /// @notice Checks if the given chain ID is supported for sending/receiving.
  /// @param chainSelector The chain to check.
  /// @return supported is true if it is supported, false if not.
  function isChainSupported(uint64 chainSelector) external view returns (bool supported);

  /// @notice Gets a list of all supported tokens which can be sent or received
  /// to/from a given chain id.
  /// @param chainSelector The chainSelector.
  /// @return tokens The addresses of all tokens that are supported.
  function getSupportedTokens(uint64 chainSelector) external view returns (address[] memory tokens);

  /// @param destinationChainSelector The destination chainSelector
  /// @param message The cross-chain CCIP message including data and/or tokens
  /// @return fee returns guaranteed execution fee for the specified message
  /// delivery to destination chain
  /// @dev returns 0 fee on invalid message.
  function getFee(
    uint64 destinationChainSelector,
    Client.EVM2AnyMessage memory message
  ) external view returns (uint256 fee);

  /// @notice Request a message to be sent to the destination chain
  /// @param destinationChainSelector The destination chain ID
  /// @param message The cross-chain CCIP message including data and/or tokens
  /// @return messageId The message ID
  /// @dev Note if msg.value is larger than the required fee (from getFee) we accept
  /// the overpayment with no refund.
  function ccipSend(
    uint64 destinationChainSelector,
    Client.EVM2AnyMessage calldata message
  ) external payable returns (bytes32);
}


// File @chainlink/contracts-ccip/src/v0.8/interfaces/OwnableInterface.sol@v0.7.6

// Original license: SPDX_License_Identifier: MIT
pragma solidity ^0.8.0;

interface OwnableInterface {
  function owner() external returns (address);

  function transferOwnership(address recipient) external;

  function acceptOwnership() external;
}


// File @chainlink/contracts-ccip/src/v0.8/ConfirmedOwnerWithProposal.sol@v0.7.6

// Original license: SPDX_License_Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title The ConfirmedOwner contract
 * @notice A contract with helpers for basic contract ownership.
 */
contract ConfirmedOwnerWithProposal is OwnableInterface {
  address private s_owner;
  address private s_pendingOwner;

  event OwnershipTransferRequested(address indexed from, address indexed to);
  event OwnershipTransferred(address indexed from, address indexed to);

  constructor(address newOwner, address pendingOwner) {
    require(newOwner != address(0), "Cannot set owner to zero");

    s_owner = newOwner;
    if (pendingOwner != address(0)) {
      _transferOwnership(pendingOwner);
    }
  }

  /**
   * @notice Allows an owner to begin transferring ownership to a new address,
   * pending.
   */
  function transferOwnership(address to) public override onlyOwner {
    _transferOwnership(to);
  }

  /**
   * @notice Allows an ownership transfer to be completed by the recipient.
   */
  function acceptOwnership() external override {
    require(msg.sender == s_pendingOwner, "Must be proposed owner");

    address oldOwner = s_owner;
    s_owner = msg.sender;
    s_pendingOwner = address(0);

    emit OwnershipTransferred(oldOwner, msg.sender);
  }

  /**
   * @notice Get the current owner
   */
  function owner() public view override returns (address) {
    return s_owner;
  }

  /**
   * @notice validate, transfer ownership, and emit relevant events
   */
  function _transferOwnership(address to) private {
    require(to != msg.sender, "Cannot transfer to self");

    s_pendingOwner = to;

    emit OwnershipTransferRequested(s_owner, to);
  }

  /**
   * @notice validate access
   */
  function _validateOwnership() internal view {
    require(msg.sender == s_owner, "Only callable by owner");
  }

  /**
   * @notice Reverts if called by anyone other than the contract owner.
   */
  modifier onlyOwner() {
    _validateOwnership();
    _;
  }
}


// File @chainlink/contracts-ccip/src/v0.8/ConfirmedOwner.sol@v0.7.6

// Original license: SPDX_License_Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title The ConfirmedOwner contract
 * @notice A contract with helpers for basic contract ownership.
 */
contract ConfirmedOwner is ConfirmedOwnerWithProposal {
  constructor(address newOwner) ConfirmedOwnerWithProposal(newOwner, address(0)) {}
}


// File @chainlink/contracts-ccip/src/v0.8/shared/access/OwnerIsCreator.sol@v0.7.6

// Original license: SPDX_License_Identifier: MIT
pragma solidity ^0.8.0;

/// @title The OwnerIsCreator contract
/// @notice A contract with helpers for basic contract ownership.
contract OwnerIsCreator is ConfirmedOwner {
  constructor() ConfirmedOwner(msg.sender) {}
}


// File @chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol@v0.8.0

// Original license: SPDX_License_Identifier: MIT
pragma solidity ^0.8.0;

interface LinkTokenInterface {
  function allowance(address owner, address spender) external view returns (uint256 remaining);

  function approve(address spender, uint256 value) external returns (bool success);

  function balanceOf(address owner) external view returns (uint256 balance);

  function decimals() external view returns (uint8 decimalPlaces);

  function decreaseApproval(address spender, uint256 addedValue) external returns (bool success);

  function increaseApproval(address spender, uint256 subtractedValue) external;

  function name() external view returns (string memory tokenName);

  function symbol() external view returns (string memory tokenSymbol);

  function totalSupply() external view returns (uint256 totalTokensIssued);

  function transfer(address to, uint256 value) external returns (bool success);

  function transferAndCall(address to, uint256 value, bytes calldata data) external returns (bool success);

  function transferFrom(address from, address to, uint256 value) external returns (bool success);
}


// File contracts/interfaces/IERC20.sol

// Original license: SPDX_License_Identifier: MIT
pragma solidity ^0.8.19;

// https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v3.0.0/contracts/token/ERC20/IERC20.sol
interface IERC20 {
    function totalSupply() external view returns (uint);

    function balanceOf(address account) external view returns (uint);

    function transfer(address recipient, uint amount) external returns (bool);

    function allowance(
        address owner,
        address spender
    ) external view returns (uint);

    function approve(address spender, uint amount) external returns (bool);

    function transferFrom(
        address sender,
        address recipient,
        uint amount
    ) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint value);
    event Approval(address indexed owner, address indexed spender, uint value);
}


// File contracts/interfaces/IERC721.sol

// Original license: SPDX_License_Identifier: UNLICENSED

pragma solidity 0.8.19;

interface IERC721 is IERC165 {
    function balanceOf(address owner) external view returns (uint balance);

    function ownerOf(uint tokenId) external view returns (address owner);

    function safeTransferFrom(address from, address to, uint tokenId) external;

    function safeTransferFrom(
        address from,
        address to,
        uint tokenId,
        bytes calldata data
    ) external;

    function transferFrom(address from, address to, uint tokenId) external;

    function approve(address to, uint tokenId) external;

    function getApproved(uint tokenId) external view returns (address operator);

    function setApprovalForAll(address operator, bool _approved) external;

    function isApprovedForAll(
        address owner,
        address operator
    ) external view returns (bool);
}


// File contracts/TradeLinkCCIPV2.sol

// Original license: SPDX_License_Identifier: UNLICENSED
pragma solidity 0.8.19;






contract TradeLinkCCIPV2 is CCIPReceiver, OwnerIsCreator {
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

    event CreateOffer(uint256 offerId, address ownerOffer);
    event CreateFulfill(uint256 fulfillId, address ownerFulfill);

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
        string[] ccipTokenOutName;
        uint256[] ccipTokenOutAmount;
        string[] ccipTokenInName;
        uint256[] ccipTokenInAmount;
        uint64 ccipTokenOutChainSelector;
        address ccipTokenOutChainAddress;
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
        string[] ccipTokenName;
        uint256[] ccipTokenAmount;
        uint64 ccipTokenChainSelector;
        address ccipTokenCahinAddress;
    }

    uint256 runningOfferId;
    uint256 runningFulfillId;
    uint64 public sourceChainSelector;
    uint256 public feePlatform;

    mapping(uint256 => Offer) public offerCollection;
    mapping(uint256 => FulfillOffer) public fulfillCollection;
    mapping(string => address) public ccipCollection;

    IRouterClient router;
    LinkTokenInterface linkToken;

    struct MessagePayload {
        uint256 step;
        uint256 offerId;
        uint256 fulfillOfferId;
        bytes fulfillInfo;
    }

    constructor(
        address _router,
        uint256 _sourceSelector,
        address _linkToken,
        address _bnm,
        address _lnm
    ) CCIPReceiver(_router) {
        router = IRouterClient(_router);
        sourceChainSelector = uint64(_sourceSelector);
        runningOfferId = 0;
        runningFulfillId = 0;
        feePlatform = 5;
        ccipCollection["BnM"] = _bnm;
        ccipCollection["LnM"] = _lnm;
        linkToken = LinkTokenInterface(_linkToken);

    }

    function _ccipReceive(
        Client.Any2EVMMessage memory any2EvmMessage
    ) internal override {
        address sender = abi.decode(any2EvmMessage.sender, (address));
        uint64 sourceSelector = any2EvmMessage.sourceChainSelector; // fetch the source chain identifier (aka selector)

        MessagePayload memory dataStruct = decodeMessagePayload(
            any2EvmMessage.data
        );

        FulfillOffer memory _fulfill = decodeFulfill(dataStruct.fulfillInfo);
        Offer memory _offer = offerCollection[dataStruct.offerId];

        if (dataStruct.step == 1) {
            if (
                !_offer.isSuccess &&
                !(_offer.deadLine < block.timestamp) &&
                validateOfferOutAndFulfillIn(_offer, _fulfill)
            ) {
                transferTokenAndNFT(dataStruct.offerId, true);
                transferCCIPToken(
                    _fulfill.ccipTokenName,
                    _fulfill.ccipTokenAmount,
                    _fulfill.traderFulfillAddress
                );

                FulfillOffer memory fulfillInfo;
                Client.EVMTokenAmount[] memory tokenAmounts;

                if (
                    _offer.ccipTokenInName.length > 0 &&
                    _offer.ccipTokenInAmount.length > 0 &&
                    _offer.ccipTokenInName.length <= 2 &&
                    _offer.ccipTokenInAmount.length <= 2
                ) {
                    tokenAmounts = checkCCIPTokenAmount(
                        _offer.ccipTokenInName,
                        _offer.ccipTokenInAmount
                    );
                    fulfillInfo.ccipTokenName = _offer.ccipTokenInName;
                    fulfillInfo.ccipTokenAmount = _offer.ccipTokenInAmount;
                    fulfillInfo.traderFulfillAddress = _offer
                        .traderOfferAddress;
                } else {
                    tokenAmounts = new Client.EVMTokenAmount[](0);
                }

                bytes memory _payload = encodedMessagePayload(
                    MessagePayload({
                        step: 2,
                        offerId: dataStruct.offerId,
                        fulfillOfferId: dataStruct.fulfillOfferId,
                        fulfillInfo: encodedFulfill(fulfillInfo)
                    })
                );

                // TODO : bypass to use linkToken for fee
                Client.EVM2AnyMessage memory evm2AnyMessage = _buildCCIPMessage(
                    sender,
                    _payload,
                    tokenAmounts,
                    address(linkToken)
                );

                _offer.isSuccess = true;

                router.ccipSend(sourceSelector, evm2AnyMessage);
            }
        }

        if (dataStruct.step == 2) {
            transferTokenAndNFT(dataStruct.fulfillOfferId, false);
            transferCCIPToken(
                _fulfill.ccipTokenName,
                _fulfill.ccipTokenAmount,
                _fulfill.traderFulfillAddress
            );
            fulfillCollection[dataStruct.fulfillOfferId].isSuccess = true;
            emit Success(
                dataStruct.offerId,
                dataStruct.fulfillOfferId,
                sourceChainSelector,
                sourceSelector,
                fulfillCollection[dataStruct.fulfillOfferId]
                    .traderFulfillAddress,
                fulfillCollection[dataStruct.fulfillOfferId].ownerFulfillAddress
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

        // TODO : Check token fee
        checkFee(_feeTokenAddress, fees);

        // TODO : transferFron token and nft
        transferFromToThis(
            _offer.tokenIn,
            _offer.tokenInAmount,
            _offer.nftIn,
            _offer.nftInId,
            _offer.ccipTokenInName,
            _offer.ccipTokenInAmount
        );

        emit CreateOffer(runningOfferId, msg.sender);

        return (runningOfferId);
    }

    function fulfillOffer(
        bytes memory _createFulfillOffer
    ) external returns (uint256 fullfillId, bytes32 messageId) {
        runningFulfillId += 1;

        bytes32 _messageId;
        Client.EVMTokenAmount[] memory tokenAmounts;

        FulfillOffer memory _fulfillInfo = decodeFulfill(_createFulfillOffer);
        address _feeTokenAddress = _fulfillInfo.feeAddress;

        fulfillCollection[runningFulfillId] = _fulfillInfo;

        // TODO : check fulfill destChainSelector = sourceChainSelector
        if (!_fulfillInfo.isBridge) {
            address fulfillTrader = offerCollection[_fulfillInfo.offerId]
                .traderOfferAddress;
            require(
                msg.sender == fulfillTrader,
                "Trader address is incorrect!"
            );

            // TODO : offer transfer to fulfill trader
            transferTokenAndNFT(_fulfillInfo.offerId, true);

            // TODO : fulfill transfer to offer trader
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
                fulfillInfo: encodedFulfill(_fulfillInfo)
            });

            bytes memory _payload = encodedMessagePayload(messagePaylaod);

            if (
                _fulfillInfo.ccipTokenAmount.length > 0 &&
                _fulfillInfo.ccipTokenName.length > 0 &&
                _fulfillInfo.ccipTokenAmount.length <= 2 &&
                _fulfillInfo.ccipTokenName.length <= 2
            ) {
                tokenAmounts = checkCCIPTokenAmount(
                    _fulfillInfo.ccipTokenName,
                    _fulfillInfo.ccipTokenAmount
                );
            } else {
                tokenAmounts = new Client.EVMTokenAmount[](0);
            }

            Client.EVM2AnyMessage memory evm2AnyMessage = _buildCCIPMessage(
                _fulfillInfo.destChainAddress,
                _payload,
                tokenAmounts,
                _feeTokenAddress
            );

            uint256 fees = _getFeeFulfillOffer(messagePaylaod);

            // TODO : Check token fee
            checkFee(_feeTokenAddress, fees);

            transferFromToThis(
                _fulfillInfo.tokenIn,
                _fulfillInfo.tokenInAmount,
                _fulfillInfo.nftIn,
                _fulfillInfo.nftInId,
                _fulfillInfo.ccipTokenName,
                _fulfillInfo.ccipTokenAmount
            );

            _messageId = router.ccipSend(
                _fulfillInfo.destChainSelector,
                evm2AnyMessage
            );
        }

        emit CreateFulfill(runningFulfillId, msg.sender);

        return (runningFulfillId, _messageId);
    }

    function checkCCIPTokenAmount(
        string[] memory ccipTokenName,
        uint256[] memory ccipTokenAmount
    ) internal view returns (Client.EVMTokenAmount[] memory) {
        Client.EVMTokenAmount[]
            memory tokenAmounts = new Client.EVMTokenAmount[](1);

        for (uint i = 0; i < ccipTokenAmount.length; i++) {
            address ccipTokenAddress = ccipCollection[ccipTokenName[i]];
            tokenAmounts[i] = Client.EVMTokenAmount({
                token: ccipTokenAddress,
                amount: ccipTokenAmount[i]
            });
        }

        return tokenAmounts;
    }

    function transferCCIPToken(
        string[] memory ccipTokenName,
        uint256[] memory ccipTokenAmount,
        address recipient
    ) internal {
        for (uint i = 0; i < ccipTokenName.length; i++) {
            address token = ccipCollection[ccipTokenName[i]];
            IERC20(token).transfer(recipient, ccipTokenAmount[i]);
        }
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
            if (fees > linkToken.balanceOf(msg.sender)) {
                revert NotEnoughBalance(linkToken.balanceOf(msg.sender), fees);
            } else {
                linkToken.transferFrom(msg.sender, address(this), fees);
                linkToken.approve(address(router), fees);
            }
        } else {
            // TODO : bypass to use linkToken for fee
            if (fees > linkToken.balanceOf(address(this))) {
                revert NotEnoughBalance(address(this).balance, fees);
            } else {
                linkToken.approve(address(router), fees);
            }
        }
    }

    function transferFromToThis(
        address[] memory tokens,
        uint256[] memory tokensAmount,
        address[] memory nfts,
        uint256[] memory nftsId,
        string[] memory ccipTokenName,
        uint256[] memory ccipTokenAmount
    ) internal {
        for (uint i = 0; i < tokens.length; i++) {
            IERC20(tokens[i]).transferFrom(
                msg.sender,
                address(this),
                tokensAmount[i]
            );
        }

        for (uint i = 0; i < ccipTokenName.length; i++) {
            address ccipToken = ccipCollection[ccipTokenName[i]];
            IERC20(ccipToken).transferFrom(
                msg.sender,
                address(this),
                ccipTokenAmount[i]
            );
            IERC20(ccipToken).approve(address(router), ccipTokenAmount[i]);
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
        string[] memory _ccipTokenName,
        uint256[] memory _ccipTokenAmount
    ) external view returns (uint256) {
        FulfillOffer memory _fulfillOffer;
        bytes memory _payload = encodedMessagePayload(
            MessagePayload({
                step: 2,
                offerId: 0,
                fulfillOfferId: _fulfillOfferId,
                fulfillInfo: encodedFulfill(_fulfillOffer)
            })
        );

        Client.EVMTokenAmount[] memory tokenAmounts;

        if (
            _ccipTokenName.length > 0 &&
            _ccipTokenName.length <= 2 &&
            _ccipTokenAmount.length > 0 &&
            _ccipTokenAmount.length <= 2
        ) {
            tokenAmounts = checkCCIPTokenAmount(
                _fulfillOffer.ccipTokenName,
                _fulfillOffer.ccipTokenAmount
            );
        } else {
            tokenAmounts = new Client.EVMTokenAmount[](0);
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

        FulfillOffer memory _fulfillOffer = decodeFulfill(
            _messagePayload.fulfillInfo
        );
        Client.EVMTokenAmount[] memory tokenAmounts;

        if (
            _fulfillOffer.ccipTokenAmount.length > 0 &&
            _fulfillOffer.ccipTokenName.length > 0 &&
            _fulfillOffer.ccipTokenAmount.length <= 2 &&
            _fulfillOffer.ccipTokenName.length <= 2
        ) {
            tokenAmounts = checkCCIPTokenAmount(
                _fulfillOffer.ccipTokenName,
                _fulfillOffer.ccipTokenAmount
            );
        } else {
            tokenAmounts = new Client.EVMTokenAmount[](0);
        }

        Client.EVM2AnyMessage memory evm2AnyMessage = _buildCCIPMessage(
            _fulfillOffer.destChainAddress,
            _payload,
            tokenAmounts,
            _fulfillOffer.feeAddress
        );

        uint256 fees = router.getFee(
            _fulfillOffer.destChainSelector,
            evm2AnyMessage
        );

        fees = ((feePlatform * fees) / 100) + fees;

        return (fees);
    }

    // TODO : Part of encode & decode
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

    function encodedFulfill(
        FulfillOffer memory _fulfillPayload
    ) public pure returns (bytes memory) {
        bytes memory encodedData = abi.encode(_fulfillPayload);
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

    // TODO : withdraw token
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
