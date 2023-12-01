import { ethers } from "hardhat";
import { setAddress } from "../utils/addressUtils";

async function main() {
  const contractName = "AstroDogNft";
  const owner = "0x443Fe6AF640C1e6DeC1eFc4468451E6765152E94";
  const nft = await ethers.deployContract(contractName, [owner]);
  const Nft = await nft.waitForDeployment();
  setAddress(contractName, await Nft.getAddress());
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
