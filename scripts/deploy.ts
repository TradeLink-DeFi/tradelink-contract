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
