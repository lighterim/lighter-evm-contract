import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { network } from "hardhat";

describe("Solady Integration", async function () {
  const { viem } = await network.connect();

  it("Should compile and deploy contract using Solady", async function () {
    const soladyExample = await viem.deployContract("SoladyExample", []);
    
    assert.ok(soladyExample.address);
    console.log("✅ SoladyExample deployed at:", soladyExample.address);
  });

  it("Should use Solady LibString", async function () {
    const soladyExample = await viem.deployContract("SoladyExample", []);
    
    // Test uint to string conversion
    const str = await soladyExample.read.uintToString([12345n]);
    assert.equal(str, "12345");
    console.log("✅ LibString.toString works:", str);
  });

  it("Should use Solady FixedPointMathLib", async function () {
    const soladyExample = await viem.deployContract("SoladyExample", []);
    
    // Calculate 25% of 1000
    const result = await soladyExample.read.calculatePercentage([1000n, 2500n]);
    assert.equal(result, 250n);
    console.log("✅ FixedPointMathLib.mulDiv works:", result.toString());
  });

  it("Should use Solady sqrt", async function () {
    const soladyExample = await viem.deployContract("SoladyExample", []);
    
    // Calculate sqrt(144) = 12
    const result = await soladyExample.read.sqrt([144n]);
    assert.equal(result, 12n);
    console.log("✅ FixedPointMathLib.sqrt works:", result.toString());
  });
});

