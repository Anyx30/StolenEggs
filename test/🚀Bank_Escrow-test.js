const { expect } = require("chai");
const { ethers } = require("hardhat");
const { constants } = require('@openzeppelin/test-helpers');
const { parseEther } = require("ethers/lib/utils");

describe("🛸Escrow Test Suite 🏦", async () =>{
   let owner, alice, bob, carol, gsm, xGsm, nft1, nft2, nft3, mock1, mock2, escrow;
   before(async () =>{
      [owner, alice, bob, carol] = await ethers.getSigners();

      const GSM = await ethers.getContractFactory('GSM');
      gsm = await GSM.deploy();

      const xGSM = await ethers.getContractFactory('xGSM');
      xGsm = await xGSM.deploy();

      const NFT1 = await ethers.getContractFactory('NFT1');
      nft1 = await NFT1.deploy();

      const NFT2 = await ethers.getContractFactory('NFT2');
      nft2 = await NFT2.deploy();

      const NFT3 = await ethers.getContractFactory('NFT3');
      nft3 = await NFT3.deploy();

      const MOCK1 = await ethers.getContractFactory('Mock1');
      mock1 = await MOCK1.deploy();

      const MOCK2 = await ethers.getContractFactory('Mock2');
      mock2 = await MOCK2.deploy();

      const spaceBank = await ethers.getContractFactory('SpaceBankEscrow');
      escrow = await spaceBank.deploy(gsm.address, xGsm.address);

      await gsm.connect(alice).mint(parseEther('500'));
      await gsm.connect(bob).mint(parseEther('500'));
      await xGsm.connect(alice).mint(parseEther('500'));
      await xGsm.connect(bob).mint(parseEther('500'));

      await gsm.connect(alice).approve(escrow.address, parseEther('1000'));
      await gsm.connect(bob).approve(escrow.address, parseEther('1000'));
      await xGsm.connect(alice).approve(escrow.address, parseEther('1000'));
      await xGsm.connect(bob).approve(escrow.address, parseEther('1000'));

      await nft1.connect(alice).mint(2);
      await nft2.connect(bob).mint(2);

      await nft1.connect(alice).setApprovalForAll(escrow.address, true);
      await nft2.connect(bob).setApprovalForAll(escrow.address, true);

      await mock1.connect(alice).mint(alice.address, 1, 2, "0x4af3246b4fff356261136f113411cb187134D675");
      await mock2.connect(bob).mint(bob.address, 2, 2, "0x3af3246b4fff354267136f113411cb187134D685");

      await mock1.connect(alice).setApprovalForAll(escrow.address, true);
      await mock2.connect(bob).setApprovalForAll(escrow.address, true);

   });

   describe("🔬Ownership transferred successfully", async () =>{
      it('Owner is transferred ownership', async () =>{
         expect(await escrow.owner()).to.eq(owner.address);
      });
   });

   describe("Trade Initiation", async () =>{
      it("Alice starts a trade initiation", async () =>{
         await escrow.connect(alice).initiateTrade([[[nft1.address], [1]],
            [[xGsm.address], [parseEther('2')]], [[mock1.address], [1], [2]]],[[[nft2.address], [1]],
            [[gsm.address], [parseEther('2')]], [[mock2.address], [2], [1]]], bob.address, 1);
      });

      it("GSM Fees paid correctly by Alice and Contract receives correctly", async () =>{
         expect(await gsm.balanceOf(escrow.address)).to.eq(parseEther("60"));
         expect(await gsm.balanceOf(alice.address)).to.eq(parseEther("440"))
      });

      it("Items are successfully received by the Contract from Alice", async () =>{
         expect(await nft1.ownerOf(1)).to.eq(escrow.address);
         expect(await xGsm.balanceOf(escrow.address)).to.eq(parseEther("2"))
         expect(await mock1.balanceOf(escrow.address,1)).to.eq(2)
      })
   });

   describe("Trade Accept", async () =>{
      it("Carol Tried to Accept the Trade and gets reverted", async () =>{
         await (expect(escrow.connect(carol).acceptTrade(1,0)).to.be.revertedWith("Not designated party"));
      })
      it("Bob Accepted the Trade intiated by Alice", async () =>{
         console.log(alice.address, bob.address, escrow.address)
         await escrow.connect(bob).acceptTrade(1, 1);
      })
   })

});