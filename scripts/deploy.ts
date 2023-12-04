import hre, { ethers } from "hardhat";
import { TradeLink__factory } from "../typechain-types";
import addresses from "../utils/addressUtils";

// npx hardhat run scripts/deploy.ts --network bkc_test

const main = async () => {
  const [owner] = await ethers.getSigners();

  const deployTradeLink = [
    {
      chainName: "sepolia",
      routerAddress: "0xd0daae2231e9cb96b94c8512223533293c3693bf",
      linkTokenAddress: "0x779877A7B0D9E8603169DdbD7836e478b4624789",
    },
    // {
    //   chainName: "mumbai",
    //   routerAddress: "0x70499c328e1e2a3c41108bd3730f6670a44595d1",
    //   linkTokenAddress: "0x326C977E6efc84E512bB9C30f76E30c160eD06FB",
    // },
  ];

  const TradeLink = (await ethers.getContractFactory(
    "TradeLink",
    owner
  )) as TradeLink__factory;

  for (let i = 0; i < deployTradeLink.length; i++) {
    const tk = await TradeLink.deploy(
      deployTradeLink[i].routerAddress,
      deployTradeLink[i].linkTokenAddress
    );
    await tk.waitForDeployment();
    const tkAddr = await tk.getAddress();
    console.log(`Deployed ${deployTradeLink[i].chainName} at ${tkAddr}`);
    await addresses.saveAddresses(hre.network.name, {
      [deployTradeLink[i].chainName]: tkAddr,
    });
  }
};

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});


// sepolia 0xB0fdbC9fcdd9b59dd478A228E55d1f21B27e81C1
// mumbai 0x379661D98224CCDE26d0277cF170839a5B6449De