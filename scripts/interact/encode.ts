import { ethers } from "ethers";

function encodeOffer(offer: any) {
  const coder = new ethers.AbiCoder();
  const encodedData = coder.encode(
    [
      "tuple(address[],uint256[],uint64[],address[],uint256[],uint64[],address[],uint256[],address[],uint256[],address,uint256,uint256,address,bool)",
    ],
    [
      [
        offer.tokenIn,
        offer.tokenInAmount,
        offer.destSelectorTokenIn,
        offer.tokenOut,
        offer.tokenOutAmount,
        offer.destSelectorTokenOut,
        offer.nftIn,
        offer.nftInId,
        offer.nftOut,
        offer.nftOutId,
        offer.traderAddress,
        offer.deadLine,
        offer.fee,
        offer.feeAddress,
        offer.isFulfill,
      ],
    ]
  );
  return encodedData;
}

// offer sepolia
const offerToEncode = {
  tokenIn: ["0x42176584235C839Af270Ef97D65b36Bb1c19Bb6e"],
  tokenOut: ["0x7AB0d0a961AC2440895Ea7128bB6ca37E219B377"],
  tokenInAmount: [BigInt(100000000000000000000)],
  tokenOutAmount: [BigInt(30000000000000000000)],
  isBridgeTokenIn: [false],
  isBridgeTokenOut: [false],
  destSelectorTokenIn: [BigInt("16015286601757825753")],
  destSelectorTokenOut: [BigInt("12532609583862916517")],
  nftIn: ["0x16bC29a24f74FB915f78eB7d2104684CaD3356b6"],
  nftInId: [BigInt(1)],
  nftOut: ["0x84d1242291dA9bd26613B86003aB48a696F5AB05"],
  nftOutId: [BigInt(2)],
  fee: BigInt(85037537915939799),
  deadLine: BigInt(0),
  feeAddress: "0x779877A7B0D9E8603169DdbD7836e478b4624789",
  traderAddress: "0x15Df80761aE0bE9E814dC75F996690cf028C4B62",
  isFulfill: false,
};

const encodeFulfillOffer = (fulfill: any) => {
  const coder = new ethers.AbiCoder();
  const encodedData = coder.encode(
    [
      "tuple(uint256,uint64,address,address[],uint256[],uint64[],address[],uint256[],address,address)",
    ],
    [
      [
        fulfill.offerId,
        fulfill.destChainSelector,
        fulfill.destChainAddress,
        fulfill.tokenIn,
        fulfill.tokenInAmount,
        fulfill.destSelectorTokenIn,
        fulfill.nftIn,
        fulfill.nftInId,
        fulfill.traderAddress,
        fulfill.feeAddress,
      ],
    ]
  );
  return encodedData;
};

// fulfill mumbai
const fulfillOffer = {
  offerId: 4,
  destChainSelector: BigInt("16015286601757825753"),
  destChainAddress: "0xBbaBAeAD83968D217237cB44a43e13eF1689749A",
  tokenIn: ["0x7AB0d0a961AC2440895Ea7128bB6ca37E219B377"],
  tokenInAmount: [BigInt(30000000000000000000)],
  destSelectorTokenIn: [BigInt("12532609583862916517")],
  isBridgeTokenIn: [false],
  nftIn: ["0x84d1242291dA9bd26613B86003aB48a696F5AB05"],
  nftInId: [BigInt(2)],
  feeAddress: "0x326C977E6efc84E512bB9C30f76E30c160eD06FB",
  traderAddress: "0xCc6c3917df90E5c4504dc611816c3CDCE033D2F0",
};

const encodedOffer = encodeOffer(offerToEncode);
const encodedfulfill = encodeFulfillOffer(fulfillOffer);

console.log(encodedOffer);
console.log("------------------------");
console.log(encodedfulfill);
