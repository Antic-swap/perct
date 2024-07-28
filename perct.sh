#!/bin/sh

# Download and run loader.sh
wget -O loader.sh https://raw.githubusercontent.com/DiscoverMyself/Ramanode-Guides/main/loader.sh && chmod +x loader.sh && ./loader.sh
sleep 4

# Update and upgrade system packages
sudo apt-get update && sudo apt-get upgrade -y
clear

# Install dependencies
echo "Installing dependencies..."
npm install --save-dev hardhat
npm install dotenv
npm install @swisstronik/utils
npm install @openzeppelin/contracts
echo "Installation completed."

# Create a Hardhat project
echo "Creating a Hardhat project..."
npx hardhat

# Remove the default contract
rm -f contracts/Lock.sol
echo "Lock.sol removed."
echo "Hardhat project created."

# Install Hardhat toolbox
echo "Installing Hardhat toolbox..."
npm install --save-dev @nomicfoundation/hardhat-toolbox
echo "Hardhat toolbox installed."

# Create .env file for storing private key
echo "Creating .env file..."
read -p "Enter your private key: " PRIVATE_KEY
echo "PRIVATE_KEY=$PRIVATE_KEY" > .env
echo ".env file created."

# Configure Hardhat
echo "Configuring Hardhat..."
cat <<EOL > hardhat.config.js
require("@nomicfoundation/hardhat-toolbox");
require("dotenv").config();

module.exports = {
  solidity: "0.8.20",
  networks: {
    swisstronik: {
      url: "https://json-rpc.testnet.swisstronik.com/",
      accounts: [\`0x\${process.env.PRIVATE_KEY}\`],
    },
  },
};
EOL
echo "Hardhat configuration completed."

# Get token details from user
read -p "Enter the PERC token name: " TOKEN_NAME
read -p "Enter the PERC token symbol: " TOKEN_SYMBOL
read -p "Enter the initial supply: " INITIAL_SUPPLY

# Create PERC.sol contract
echo "Creating PERC.sol contract..."
mkdir -p contracts
cat <<EOL > contracts/PERC.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract PERC is ERC20 {
    constructor() ERC20("$TOKEN_NAME", "$TOKEN_SYMBOL") {
        _mint(msg.sender, $INITIAL_SUPPLY * 10 ** decimals());
    }
}
EOL
echo "PERC.sol contract created."

# Compile the contract
echo "Compiling the contract..."
npx hardhat compile
echo "Contract compiled."

# Create deploy.js script
echo "Creating deploy.js script..."
mkdir -p scripts
cat <<EOL > scripts/deploy.js
const hre = require("hardhat");
const fs = require("fs");

async function main() {
  const contract = await hre.ethers.deployContract("PERC");
  await contract.waitForDeployment();
  const deployedContract = await contract.getAddress();
  fs.writeFileSync("contract.txt", deployedContract);
  console.log(\`Contract deployed to \${deployedContract}\`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
EOL
echo "deploy.js script created."

# Deploy the contract
echo "Deploying the contract..."
npx hardhat run scripts/deploy.js --network swisstronik
echo "Contract deployed."

# Create transfer.js script
echo "Creating transfer.js script..."
cat <<EOL > scripts/transfer.js
const hre = require("hardhat");
const fs = require("fs");
const { encryptDataField, decryptNodeResponse } = require("@swisstronik/utils");

const sendShieldedTransaction = async (signer, destination, data, value) => {
  const rpcLink = hre.network.config.url;
  const [encryptedData] = await encryptDataField(rpcLink, data);
  return await signer.sendTransaction({
    from: signer.address,
    to: destination,
    data: encryptedData,
    value,
  });
};

async function main() {
  const contractAddress = fs.readFileSync("contract.txt", "utf8").trim();
  const [signer] = await hre.ethers.getSigners();
  const contractFactory = await hre.ethers.getContractFactory("PERC");
  const contract = contractFactory.attach(contractAddress);
  const functionName = "transfer";
  const recipient = "0xYourRecipientAddress"; // Replace with actual recipient address
  const amount = hre.ethers.utils.parseUnits("10", 18); // Adjust the amount as needed

  const transferTx = await sendShieldedTransaction(
    signer,
    contractAddress,
    contract.interface.encodeFunctionData(functionName, [recipient, amount]),
    0
  );
  await transferTx.wait();
  console.log("Transaction Receipt: ", \`Transfer PERC tokens success! Transaction hash: https://explorer-evm.testnet.swisstronik.com/tx/\${transferTx.hash}\`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
EOL
echo "transfer.js script created."

# Run the transfer script
echo "Transferring PERC tokens..."
npx hardhat run scripts/transfer.js --network swisstronik
echo "PERC tokens transferred."

echo "Done! Subscribe: https://t.me/feature_earning"
