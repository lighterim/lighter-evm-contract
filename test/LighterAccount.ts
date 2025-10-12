import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { network } from "hardhat";
import { parseEther } from "viem";

describe("LighterAccount Integration", async function () {
  const { viem } = await network.connect();
  const publicClient = await viem.getPublicClient();
  const [owner, user1, user2] = await viem.getWalletClients();

  describe("Complete Deployment and Minting Flow", function () {
    it("Should deploy all contracts successfully", async function () {
      // Deploy LighterTicket
      const lighterNFT = await viem.deployContract("LighterTicket", [
        "Lighter Ticket",
        "LTKT",
        "https://api.lighter.xyz/metadata/",
      ]);
      
      assert.ok(lighterNFT.address);

      // Deploy ERC6551Registry
      const registry = await viem.deployContract("ERC6551Registry", []);
      assert.ok(registry.address);

      // Deploy AccountV3Simplified implementation
      const accountImpl = await viem.deployContract("AccountV3Simplified", []);
      assert.ok(accountImpl.address);

      // Deploy LighterAccount
      const mintPrice = parseEther("0.01");
      const minter = await viem.deployContract("LighterAccount", [
        lighterNFT.address,
        registry.address,
        accountImpl.address,
        mintPrice,
      ]);
      assert.ok(minter.address);

      // Transfer NFT ownership to Minter
      await lighterNFT.write.transferOwnership([minter.address]);
      const nftOwner = await lighterNFT.read.owner();
      assert.equal(nftOwner.toLowerCase(), minter.address.toLowerCase());
    });

    it("Should mint NFT with TBA", async function () {
      // Setup
      const lighterNFT = await viem.deployContract("LighterTicket", [
        "Lighter Ticket",
        "LTKT",
        "https://api.lighter.xyz/metadata/",
      ]);
      
      const registry = await viem.deployContract("ERC6551Registry", []);
      const accountImpl = await viem.deployContract("AccountV3Simplified", []);
      
      const mintPrice = parseEther("0.01");
      const minter = await viem.deployContract("LighterAccount", [
        lighterNFT.address,
        registry.address,
        accountImpl.address,
        mintPrice,
      ]);
      
      await lighterNFT.write.transferOwnership([minter.address]);

      // Mint with TBA as user1
      const minterAsUser1 = await viem.getContractAt(
        "LighterAccount",
        minter.address,
        { client: { wallet: user1 } }
      );

      const balanceBefore = await publicClient.getBalance({
        address: minter.address,
      });

      // Create account with TBA
      const nostrPubKey = "0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef";
      const result = await minterAsUser1.write.createAccount(
        [user1.account.address, nostrPubKey],
        { value: mintPrice }
      );

      // Check NFT ownership
      const tokenId = 1n;
      const nftOwner = await lighterNFT.read.ownerOf([tokenId]);
      assert.equal(nftOwner.toLowerCase(), user1.account.address.toLowerCase());

      // Check minter received payment
      const balanceAfter = await publicClient.getBalance({
        address: minter.address,
      });
      assert.equal(balanceAfter - balanceBefore, mintPrice);

      // Check total rented
      const totalRented = await minter.read.totalRented();
      assert.equal(totalRented, 1n);
    });

    it("Should get TBA address for minted NFT", async function () {
      // Setup
      const lighterNFT = await viem.deployContract("LighterTicket", [
        "Lighter Ticket",
        "LTKT",
        "",
      ]);
      
      const registry = await viem.deployContract("ERC6551Registry", []);
      const accountImpl = await viem.deployContract("AccountV3Simplified", []);
      
      const minter = await viem.deployContract("LighterAccount", [
        lighterNFT.address,
        registry.address,
        accountImpl.address,
        parseEther("0.01"),
      ]);
      
      await lighterNFT.write.transferOwnership([minter.address]);

      // Mint NFT
      const minterAsUser1 = await viem.getContractAt(
        "LighterAccount",
        minter.address,
        { client: { wallet: user1 } }
      );
      const nostrPubKey = "0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef";
      await minterAsUser1.write.createAccount([user1.account.address, nostrPubKey], {
        value: parseEther("0.01"),
      });

      // Get TBA address
      const tokenId = 1n;
      const tbaAddress = await minter.read.getAccountAddress([tokenId]);

      // Verify it's a valid address
      assert.ok(tbaAddress);
      assert.equal(tbaAddress.length, 42);
      assert.ok(tbaAddress.startsWith("0x"));

      // Verify TBA has code (deployed)
      const code = await publicClient.getCode({ address: tbaAddress });
      assert.notEqual(code, undefined);
      assert.notEqual(code, "0x");
    });

    it("Should create multiple accounts with TBAs", async function () {
      // Setup
      const lighterNFT = await viem.deployContract("LighterTicket", [
        "Lighter Ticket",
        "LTKT",
        "",
      ]);
      
      const registry = await viem.deployContract("ERC6551Registry", []);
      const accountImpl = await viem.deployContract("AccountV3Simplified", []);
      
      const mintPrice = parseEther("0.01");
      const minter = await viem.deployContract("LighterAccount", [
        lighterNFT.address,
        registry.address,
        accountImpl.address,
        mintPrice,
      ]);
      
      await lighterNFT.write.transferOwnership([minter.address]);

      // Create multiple accounts
      const count = 3;
      const nostrPubKey = "0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef";
      
      const minterAsUser1 = await viem.getContractAt(
        "LighterAccount",
        minter.address,
        { client: { wallet: user1 } }
      );

      // Create accounts one by one
      for (let i = 0; i < count; i++) {
        await minterAsUser1.write.createAccount([user1.account.address, nostrPubKey], {
          value: mintPrice,
        });
      }

      // Check balance
      const balance = await lighterNFT.read.balanceOf([user1.account.address]);
      assert.equal(balance, BigInt(count));

      // Check total rented
      const totalRented = await minter.read.totalRented();
      assert.equal(totalRented, BigInt(count));

      // Verify each NFT has a TBA
      for (let i = 1; i <= count; i++) {
        const owner = await lighterNFT.read.ownerOf([BigInt(i)]);
        assert.equal(owner.toLowerCase(), user1.account.address.toLowerCase());

        const tbaAddress = await minter.read.getAccountAddress([BigInt(i)]);
        const code = await publicClient.getCode({ address: tbaAddress });
        assert.notEqual(code, "0x");
      }
    });

    it("Should reject insufficient payment", async function () {
      // Setup
      const lighterNFT = await viem.deployContract("LighterTicket", [
        "Lighter Ticket",
        "LTKT",
        "",
      ]);
      
      const registry = await viem.deployContract("ERC6551Registry", []);
      const accountImpl = await viem.deployContract("AccountV3Simplified", []);
      
      const mintPrice = parseEther("0.01");
      const minter = await viem.deployContract("LighterAccount", [
        lighterNFT.address,
        registry.address,
        accountImpl.address,
        mintPrice,
      ]);
      
      await lighterNFT.write.transferOwnership([minter.address]);

      // Try to create account with insufficient payment
      const minterAsUser1 = await viem.getContractAt(
        "LighterAccount",
        minter.address,
        { client: { wallet: user1 } }
      );

      const nostrPubKey = "0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef";
      const insufficientAmount = parseEther("0.005");
      
      await assert.rejects(
        minterAsUser1.write.createAccount([user1.account.address, nostrPubKey], {
          value: insufficientAmount,
        })
      );
    });

    it("Should update rent price", async function () {
      // Setup
      const lighterNFT = await viem.deployContract("LighterTicket", [
        "Lighter Ticket",
        "LTKT",
        "",
      ]);
      
      const registry = await viem.deployContract("ERC6551Registry", []);
      const accountImpl = await viem.deployContract("AccountV3Simplified", []);
      
      const initialPrice = parseEther("0.01");
      const minter = await viem.deployContract("LighterAccount", [
        lighterNFT.address,
        registry.address,
        accountImpl.address,
        initialPrice,
      ]);

      // Update price
      const newPrice = parseEther("0.02");
      await minter.write.setRentPrice([newPrice]);

      // Verify
      const currentPrice = await minter.read.rentPrice();
      assert.equal(currentPrice, newPrice);
    });

    it("Should track ticket receipts correctly", async function () {
      // Setup
      const lighterNFT = await viem.deployContract("LighterTicket", [
        "Lighter Ticket",
        "LTKT",
        "",
      ]);
      
      const registry = await viem.deployContract("ERC6551Registry", []);
      const accountImpl = await viem.deployContract("AccountV3Simplified", []);
      
      const mintPrice = parseEther("0.01");
      const minter = await viem.deployContract("LighterAccount", [
        lighterNFT.address,
        registry.address,
        accountImpl.address,
        mintPrice,
      ]);
      
      await lighterNFT.write.transferOwnership([minter.address]);

      // Create account
      const minterAsUser1 = await viem.getContractAt(
        "LighterAccount",
        minter.address,
        { client: { wallet: user1 } }
      );
      
      const nostrPubKey = "0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef";
      await minterAsUser1.write.createAccount([user1.account.address, nostrPubKey], {
        value: mintPrice,
      });

      // Check contract balance
      const contractBalance = await publicClient.getBalance({
        address: minter.address,
      });
      assert.equal(contractBalance, mintPrice);

      // Check total rented
      const totalRented = await minter.read.totalRented();
      assert.equal(totalRented, 1n);
    });
  });
});

