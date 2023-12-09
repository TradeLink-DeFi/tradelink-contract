import { ethers } from "hardhat";
import { setAddress } from "../utils/addressUtils";
import nftlists from "../constants/nftlist";

async function main() {
  const contractName = ["USDT", "USDC"];
  const [owner] = await ethers.getSigners();

  const _token = await ethers.deployContract(contractName[0], [owner]);
  const token = await _token.waitForDeployment();
  setAddress(contractName[0], await token.getAddress());
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
