// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const { ethers } = require("hardhat");
const hre = require("hardhat");

async function main() {
  // Hardhat always runs the compile task when running scripts with its command
  // line interface.
  //
  // If this script is run directly using `node` you may want to call compile
  // manually to make sure everything is compiled
  // await hre.run('compile');

  // We get the contract to deploy

  const Grav = await hre.ethers.getContractFactory("Token");
  const grav = await Grav.deploy();
  console.log("Grav deployed to:", grav.address);
  const Usdc = await hre.ethers.getContractFactory("Usdc");
  const usdc = await Usdc.deploy();
  console.log("USDC deployed to:", usdc.address);

  const Incubator = await hre.ethers.getContractFactory("VoucherIncubator");
  const incubator = await Incubator.deploy(usdc.address);

  console.log("Incubator deployed to:", incubator.address);
  const Voucher = await hre.ethers.getContractFactory("WhitelistVoucher");
  const voucher = await Voucher.deploy(grav.address);
  console.log("Voucher deployed to:", voucher.address);

  const Egg = await hre.ethers.getContractFactory("Eggs");
  const egg = await Egg.deploy(
    grav.address,
    usdc.address,
    voucher.address,
    incubator.address,
    "0xE2Ccad70370800c5319261Be716B41732F802f62"
  );
  await egg.deployed();

  console.log("Eggs deployed to:", egg.address);
  await incubator.changeEggContract(egg.address);

  await hre.run("verify:verify", {
    address: grav.address,
    contract: "contracts/Mocks/Token.sol:Token",
    network: "harmony",
  });

  await hre.run("verify:verify", {
    address: usdc.address,
    contract: "contracts/Mocks/Usdc.sol:Usdc",
    network: "harmony",
  });

  await hre.run("verify:verify", {
    address: incubator.address,
    constructorArguments: [usdc.address],
    contract: "contracts/VoucherIncubator.sol:VoucherIncubator",
    network: "harmony",
  });

  await hre.run("verify:verify", {
    address: voucher.address,
    constructorArguments: [grav.address],
    contract: "contracts/WhitelistVoucher.sol:WhitelistVoucher",
    network: "harmony",
  });

  await hre.run("verify:verify", {
    address: egg.address,
    constructorArguments: [
      grav.address,
      usdc.address,
      voucher.address,
      incubator.address,
      "0xE2Ccad70370800c5319261Be716B41732F802f62",
    ],
    contract: "contracts/Eggs.sol:Eggs",
    network: "harmony",
  });
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
