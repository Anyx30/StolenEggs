const { expect } = require("chai");
const { parseEther, parseUnits } = require("ethers/lib/utils");
const { ethers, network, utils } = require("hardhat");
const { BigNumber } = require("ethers");
describe("OneVerse 🥚 Test Suite Phase-II", async () =>{
   let owner, alice, bob, carol, grav, usdc, incubator, whitelist, eggs, hardhatVrfCoordinatorV2Mock;
   before(async () =>{
      [owner, alice, bob, carol] = await ethers.getSigners();
      let gravToken = await ethers.getContractFactory('Grav');
      grav = await gravToken.deploy();
      let usdcToken = await ethers.getContractFactory('Usdc');
      usdc = await usdcToken.deploy();
      let voucher = await ethers.getContractFactory('VoucherIncubator');
      incubator = await voucher.deploy(usdc.address);
      let whitelistVoucher = await ethers.getContractFactory('WhitelistVoucher');
      whitelist = await whitelistVoucher.deploy(grav.address);

      let eggNFT = await ethers.getContractFactory('Eggs');
      let vrfCoordinatorV2Mock =  await ethers.getContractFactory("VRFCoordinatorV2Mock");
      hardhatVrfCoordinatorV2Mock = await vrfCoordinatorV2Mock.deploy(0, 0);
      await hardhatVrfCoordinatorV2Mock.createSubscription();
      await hardhatVrfCoordinatorV2Mock.fundSubscription(1, ethers.utils.parseEther("7"))
      eggs = await eggNFT.deploy(grav.address, usdc.address, whitelist.address, incubator.address,
          owner.address, hardhatVrfCoordinatorV2Mock.address, 1);

      await incubator.changeEggContract(eggs.address);

      await usdc.connect(alice).mint(100);
      await usdc.connect(carol).mint(100);
      await usdc.connect(bob).mint(100);
      await grav.connect(bob).mint(100);

      await whitelist.connect(alice).setApprovalForAll(eggs.address, true);
      await whitelist.connect(bob).setApprovalForAll(eggs.address, true);
      await usdc.connect(alice).approve(eggs.address, parseEther('1000'));
      await usdc.connect(bob).approve(eggs.address, parseEther('1000'));
      await usdc.connect(carol).approve(eggs.address, parseEther('1000'));
      await grav.connect(bob).approve(eggs.address, parseEther('1000'));

      await incubator.connect(alice).setApprovalForAll(eggs.address, true);


   });

   describe("Test Suite Launched", async () =>{
      it("Ownership transferred to Owner", async () =>{
         expect(await eggs.owner()).to.eq(owner.address);
      });
   })

   describe("🐔Phase I", async () =>{
      it("Alice & Bob buys voucher", async () =>{
         await whitelist.connect(alice).mintWhitelistVoucherNFT(1, 4);
         await whitelist.connect(bob).mintWhitelistVoucherNFT(2, 2);
      });

      it("Eggs Minted", async () => {
         await eggs.connect(alice).mint([0,1,2,3], true);
         let requestIdStorage = await eggs.requestMapper(alice.address, 0);
         console.log(requestIdStorage);
         await hardhatVrfCoordinatorV2Mock.fulfillRandomWords(1, eggs.address);
         await hardhatVrfCoordinatorV2Mock.fulfillRandomWords(2, eggs.address);
         await hardhatVrfCoordinatorV2Mock.fulfillRandomWords(3, eggs.address);
         await hardhatVrfCoordinatorV2Mock.fulfillRandomWords(4, eggs.address);
         expect(await usdc.balanceOf(owner.address)).to.eq(parseUnits('154', 6));
      });

      it("Alice Eggs balance gets updated", async () =>{
         expect(await eggs.balanceOf(alice.address)).to.eq(4);
         expect(await eggs.ownerOf(1)).to.eq(alice.address);
      });

   });

   describe("🐔Phase II Test suite", async () =>{
      it("Phase I toggled and USDC Payment allowed", async () =>{
         await eggs.togglePhase1();
         await eggs.toggleUSDCPayment();
      });

      it("Bob buys eggs", async () =>{
         await eggs.connect(bob).mint([4], true);
         await hardhatVrfCoordinatorV2Mock.fulfillRandomWords(5, eggs.address);
         expect(await eggs.balanceOf(bob.address)).to.eq(2);
         expect(await eggs.ownerOf(5)).to.eq(bob.address);
         expect(await eggs.ownerOf(6)).to.eq(bob.address);
      });

      it("USDC payment got deducted", async () =>{
         expect(await usdc.balanceOf(owner.address)).to.eq(parseUnits('242', 6));
      });

      it('USDC payment stopped and toggled to grav fees', async () =>{
         await eggs.toggleUSDCPayment();
         await eggs.toggleGravPayment();
         await eggs.setGravFee([parseEther('10'), parseEther('15')]);
         await eggs.connect(bob).mint([5], false);
         await hardhatVrfCoordinatorV2Mock.fulfillRandomWords(6, eggs.address);
         expect(await eggs.balanceOf(bob.address)).to.eq(4);
         expect(await eggs.ownerOf(7)).to.eq(bob.address);
         expect(await eggs.ownerOf(8)).to.eq(bob.address);
         expect(await grav.balanceOf(owner.address)).to.eq(parseEther('20'));
      });

      describe("🐔Buying Incubator", async () =>{
         it("Toggle Incubator Sale and setting incubator fees", async () =>{
            await eggs.toggleIncubatorSale();
            await eggs.setIncubatorFee(parseEther('15'))
         });

         it("Bob buys Incubator", async () =>{
            await eggs.connect(bob).buyIncubator([7, 8]);
            await hardhatVrfCoordinatorV2Mock.fulfillRandomWords(7, eggs.address);
            expect(await grav.balanceOf(owner.address)).to.eq(parseEther('50'));
         });

         it("Incubator must be added to the egg", async () =>{
            let eggMetadataOf7 = await eggs.EggsMetadata(7);
            expect(eggMetadataOf7[4]).to.eq(true);
            let eggMetadataOf8 = await eggs.EggsMetadata(8);
            expect(eggMetadataOf8[4]).to.eq(true);
         });
      });

      describe("🐔 Reedeeming Incubators with vouchers", async () =>{
         it("Alice redeems Incubators as she bought eggs during phase I", async () =>{
            expect(await incubator.ownerOf(0)).to.eq(alice.address);
            expect(await eggs.ownerOf(1)).to.eq(alice.address);
            let eggMetadataOf2 = await eggs.EggsMetadata(3);
            expect(eggMetadataOf2[4]).to.eq(false);
            await eggs.connect(alice).redeemIncubator([1,3,4], [0,2,3]);
            await hardhatVrfCoordinatorV2Mock.fulfillRandomWords(8, eggs.address);
            let newEggMetadataOf2 = await eggs.EggsMetadata(3);
            expect(newEggMetadataOf2[4]).to.eq(true);
         });
      });

      describe("🐔 Phase III Testing: Public Mint", async () =>{
         it("Turning off whitelist phase", async () =>{
            await eggs.toggleWLPhase();
            await eggs.toggleUSDCPayment();
         });

         it("Carol buys Eggs", async () =>{
            await eggs.connect(carol).publicMint(7, true);
            await hardhatVrfCoordinatorV2Mock.fulfillRandomWords(9, eggs.address);
            expect(await usdc.balanceOf(owner.address)).to.eq(parseUnits('627', 6));
         })

         it("Turning off USDC mode and convert to GRAV", async () =>{
            await eggs.connect(carol).publicMint(4, true);
            await hardhatVrfCoordinatorV2Mock.fulfillRandomWords(10, eggs.address);
            // expect(await usdc.balanceOf(owner.address)).to.eq(parseUnits('627', 6));
         });
      });
   });
});