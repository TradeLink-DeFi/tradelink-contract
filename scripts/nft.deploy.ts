import { ethers } from "hardhat";
import { setAddress } from "../utils/addressUtils";
import nftlists from "../constants/nftlist";

async function main() {
  const contractName = nftlists.AstroDogNft;
  const owner = process.env.ADMIN_ADDRESS;
  const nft = await ethers.deployContract(contractName, [owner]);
  const Nft = await nft.waitForDeployment();
  setAddress(contractName, await Nft.getAddress());
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
