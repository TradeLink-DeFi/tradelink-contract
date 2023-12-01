import * as fs from "fs";
import hre from "hardhat";

const getAddressPath = (networkName: string) =>
  `${__dirname}/../addressList/${networkName}.json`;

const getAddressList = async (
  networkName: string
): Promise<Record<string, string>> => {
  const addressPath = getAddressPath(networkName);
  try {
    const data = fs.readFileSync(addressPath);
    return JSON.parse(data.toString());
  } catch (e) {
    return {};
  }
};

const saveAddresses = async (
  networkName: string,
  newAddrList: Record<string, string>
) => {
  const addressPath = getAddressPath(networkName);
  const addressList = await getAddressList(networkName);

  const pathArr = addressPath.split("/");
  const dirPath = [...pathArr].slice(0, pathArr.length - 1).join("/");

  if (!fs.existsSync(dirPath)) fs.mkdirSync(dirPath);

  return fs.writeFileSync(
    addressPath,
    JSON.stringify({
      ...addressList,
      ...newAddrList,
    })
  );
};

export const setAddress = (
  key: string,
  value: string,
  networkName = hre.network.name
) => {
  const addressPath = getAddressPath(networkName);
  const addressList = getAllAddressList();

  const pathArr = addressPath.split("/");
  const dirPath = [...pathArr].slice(-1).join("/");

  if (!fs.existsSync(dirPath)) {
    fs.mkdirSync(dirPath);
  }

  try {
    fs.writeFileSync(
      addressPath,
      JSON.stringify({ ...addressList, [key]: value })
    );
    return true;
  } catch (e) {
    return false;
  }
};

export const getAllAddressList = (
  networkName = hre.network.name
): Record<string, string> => {
  const addressPath = getAddressPath(networkName);
  try {
    const data = fs.readFileSync(addressPath);
    return JSON.parse(data.toString());
  } catch (e) {
    return {};
  }
};

export default {
  getAddressPath,
  getAddressList,
  saveAddresses,
  setAddress,
};
