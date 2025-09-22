import { network } from "hardhat";

async function main() {
  console.log("Deploying to Base Sepolia...");
  
  // Connect to Base Sepolia network
  const { viem } = await network.connect({ network: "baseSepolia", chainType: "generic" });
  
  // Deploy the Counter contract
  const counter = await viem.deployContract("Counter");
  
  console.log("Deployment completed!");
  console.log("Counter contract deployed at:", counter.address);
  
  // Verify the deployment by calling a function
  const currentValue = await counter.read.x();
  console.log("Initial counter value:", currentValue.toString());
  
  // Call incBy function to test the contract
  console.log("Calling incBy(5)...");
  await counter.write.incBy([5n]);
  
  const newValue = await counter.read.x();
  console.log("Counter value after incBy(5):", newValue.toString());
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  }); 