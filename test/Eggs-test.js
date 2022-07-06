const { expect } = require("chai");
const { parseEther, parseUnits } = require("ethers/lib/utils");
const { ethers, network, utils } = require("hardhat");
const { BigNumber } = require("ethers");
describe("OneVerse 🥚 Test Suite Phase-II", async () =>{
   let owner, alice, bob, grav, usdc, incubator, whitelist, eggs;
   let hardhatVrfCoordinatorV2Mock;
   before(async () =>{
      [owner, alice, bob] = await ethers.getSigners();
      // let gravToken = await ethers.getContractFactory('Grav');
      // grav = await gravToken.deploy();
      // let usdcToken = await ethers.getContractFactory('Usdc');
      // usdc = await usdcToken.deploy();
      // let voucher = await ethers.getContractFactory('VoucherIncubator');
      // incubator = await voucher.deploy(usdc.address);
      // let whitelistVoucher = await ethers.getContractFactory('WhitelistVoucher');
      // whitelist = await whitelistVoucher.deploy(grav.address);

      let eggNFT = await ethers.getContractFactory('Eggs');
      let vrfCoordinatorV2Mock =  await ethers.getContractFactory("VRFCoordinatorV2Mock");
      hardhatVrfCoordinatorV2Mock = await vrfCoordinatorV2Mock.deploy(0, 0);
      await hardhatVrfCoordinatorV2Mock.createSubscription();
      await hardhatVrfCoordinatorV2Mock.fundSubscription(1, ethers.utils.parseEther("7"))
      eggs = await eggNFT.deploy(hardhatVrfCoordinatorV2Mock.address,1);


   });
   it("Contract should request Random numbers successfully", async () => {
      console.log(await eggs.s_subscriptionId())
      console.log(await eggs.vrfCoordinator())
      // await eggs.mint([1,2,3])
      await expect (eggs.mint([1,2])).to.emit(
          hardhatVrfCoordinatorV2Mock,
          "RandomWordsRequested"
      );
   });
   it("Coordinator should fulfill Random Number request", async () => {
      expect(await eggs.balanceOf(alice.address)).to.eq('0')
      await eggs.connect(alice).mint([3,4]);
      await expect(
          hardhatVrfCoordinatorV2Mock.fulfillRandomWords(3, eggs.address)
      ).to.emit(hardhatVrfCoordinatorV2Mock, "RandomWordsFulfilled")
      expect(await eggs.balanceOf(alice.address)).to.eq('3')
   });
});