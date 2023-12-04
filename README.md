# Sample Hardhat Project

This project demonstrates a basic Hardhat use case. It comes with a sample contract, a test for that contract, and a script that deploys that contract.

Try running some of the following tasks:

```shell
npx hardhat help
npx hardhat test
REPORT_GAS=true npx hardhat test
npx hardhat node
npx hardhat run scripts/deploy.ts
```

Deploy

```shell
$ npx hardhat run --network {network_name} scripts/{script_name}.ts
```

Flatten

```shell
$ npx hardhat flatten contracts/{contract_name}.sol > {flatten_folder}/{flatten_name}.sol
```

Verify

```shell
npx hardhat verify --network {network_name} {contract_address} "{constructor_parameter1}"
npx hardhat verify --contract contracts/{contract_name}.sol:{contract_name} --network {network} {contract_address} "{constructor_parameter1}"
```

npx hardhat verify --contract contracts/Golem8bitNft.sol:Golem8bitNft --network avalanceFuji 0xf7F023d94E013De2239f9827BC242772763d1456 "0x443Fe6AF640C1e6DeC1eFc4468451E6765152E94"
