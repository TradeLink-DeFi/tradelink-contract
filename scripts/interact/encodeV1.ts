import { ethers } from "ethers";

function encodeOffer(offer: any) {
  const coder = new ethers.AbiCoder();
  const encodedData = coder.encode(
    [
      "tuple(address[],uint256[],address[],uint256[],uint64,address[],uint256[],address[],uint256[],address,address,uint256,uint256,address,bool)",
    ],
    [
      [
        offer.tokenIn,
        offer.tokenInAmount,
        offer.nftIn,
        offer.nftInId,
        offer.destSelectorOut,
        offer.tokenOut,
        offer.tokenOutAmount,
        offer.nftOut,
        offer.nftOutId,
        offer.ownerOfferAddress,
        offer.traderOfferAddress,
        offer.deadLine,
        offer.fee,
        offer.feeAddress,
        offer.isSuccess,
      ],
    ]
  );
  return encodedData;
}

const encodeFulfillOffer = (fulfill: any) => {
  const coder = new ethers.AbiCoder();
  const encodedData = coder.encode(
    [
      "tuple(uint256,uint64,address,address[],uint256[],address[],uint256[],address,address,address,bool,bool)",
    ],
    [
      [
        fulfill.offerId,
        fulfill.destChainSelector,
        fulfill.destChainAddress,
        fulfill.tokenIn,
        fulfill.tokenInAmount,
        fulfill.nftIn,
        fulfill.nftInId,
        fulfill.feeAddress,
        fulfill.ownerFulfillAddress,
        fulfill.traderFulfillAddress,
        fulfill.isBridge,
        fulfill.isSuccess,
      ],
    ]
  );
  return encodedData;
};

// offer sepolia
const offerToEncode = {
  tokenIn: ["0x42176584235C839Af270Ef97D65b36Bb1c19Bb6e"],
  tokenInAmount: [BigInt(100000000000000000000)],
  nftIn: ["0x16bC29a24f74FB915f78eB7d2104684CaD3356b6"],
  nftInId: [BigInt(2)],
  destSelectorOut: BigInt(""),
  tokenOut: ["0x7AB0d0a961AC2440895Ea7128bB6ca37E219B377"],
  tokenOutAmount: [BigInt(30000000000000000000)],
  nftOut: ["0x84d1242291dA9bd26613B86003aB48a696F5AB05"],
  nftOutId: [BigInt(2)],
  ownerOfferAddress: "0xCc6c3917df90E5c4504dc611816c3CDCE033D2F0",
  traderOfferAddress: "0x15Df80761aE0bE9E814dC75F996690cf028C4B62",
  deadLine: BigInt(0),
  fee: BigInt(84942352680556055),
  feeAddress: "0x779877A7B0D9E8603169DdbD7836e478b4624789",
  isSuccess: false,
};

// fulfill mumbai
const fulfillOffer = {
  offerId: BigInt(1),
  destChainSelector: BigInt("16015286601757825753"),
  destChainAddress: "0xE3e914294fef9F2eFFC95979334Bf2292974D217",
  tokenIn: ["0x7AB0d0a961AC2440895Ea7128bB6ca37E219B377"],
  tokenInAmount: [BigInt(30000000000000000000)],
  nftIn: ["0x84d1242291dA9bd26613B86003aB48a696F5AB05"],
  nftInId: [BigInt(2)],
  feeAddress: "0x326C977E6efc84E512bB9C30f76E30c160eD06FB",
  ownerFulfillAddress: "0x15Df80761aE0bE9E814dC75F996690cf028C4B62",
  traderFulfillAddress: "0xCc6c3917df90E5c4504dc611816c3CDCE033D2F0",
  isBridge: true,
  isSuccess: false,
};

const offerToEncodeSepolia = {
  tokenIn: ["0x42176584235C839Af270Ef97D65b36Bb1c19Bb6e"],
  tokenInAmount: [BigInt(100000000000000000000)],
  nftIn: [],
  nftInId: [],
  destSelectorOut: BigInt(""),
  tokenOut: ["0x42176584235C839Af270Ef97D65b36Bb1c19Bb6e"],
  tokenOutAmount: [BigInt(30000000000000000000)],
  nftOut: [],
  nftOutId: [],
  ownerOfferAddress: "0xCc6c3917df90E5c4504dc611816c3CDCE033D2F0",
  traderOfferAddress: "0x15Df80761aE0bE9E814dC75F996690cf028C4B62",
  deadLine: BigInt(0),
  fee: BigInt(0),
  feeAddress: "0x779877A7B0D9E8603169DdbD7836e478b4624789",
  isSuccess: false,
};

const fulfillOfferSepolia = {
  offerId: BigInt(3),
  destChainSelector: BigInt("16015286601757825753"),
  destChainAddress: "0xE3e914294fef9F2eFFC95979334Bf2292974D217",
  tokenIn: ["0x42176584235C839Af270Ef97D65b36Bb1c19Bb6e"],
  tokenInAmount: [BigInt(30000000000000000000)],
  nftIn: [],
  nftInId: [],
  feeAddress: "0x779877A7B0D9E8603169DdbD7836e478b4624789",
  ownerFulfillAddress: "0x15Df80761aE0bE9E814dC75F996690cf028C4B62",
  traderFulfillAddress: "0xCc6c3917df90E5c4504dc611816c3CDCE033D2F0",
  isBridge: true,
};

// const encodedOffer = encodeOffer(offerToEncode);
// const encodedfulfill = encodeFulfillOffer(fulfillOffer);

const encodedOffer = encodeOffer(offerToEncodeSepolia);
const encodedfulfill = encodeFulfillOffer(fulfillOfferSepolia);

console.log(encodedOffer);
console.log("------------------------");
console.log(encodedfulfill);
