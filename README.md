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
```
