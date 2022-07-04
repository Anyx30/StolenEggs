const { expect } = require("chai");
const { parseEther, parseUnits } = require("ethers/lib/utils");
const { ethers, network } = require("hardhat");

describe("OneVerse 🥚 Test Suite Phase-II", async () =>{
   let owner, alice, bob, grav, usdc, incubator, whitelist, eggs;
   before(async () =>{
      [owner, alice, bob] = await ethers.getSigners();
      let gravToken = await ethers.getContractFactory('Grav');
      grav = await gravToken.deploy();
      let usdcToken = await ethers.getContractFactory('Usdc');
      usdc = await usdcToken.deploy();
      let voucher = await ethers.getContractFactory('VoucherIncubator');
      incubator = await voucher.deploy(usdc.address);
      let whitelistVoucher = await ethers.getContractFactory('WhitelistVoucher');
      whitelist = await whitelistVoucher.deploy(grav.address);

      let eggNFT = await ethers.getContractFactory('Eggs');
      eggs = await eggNFT.deploy();
   });
});