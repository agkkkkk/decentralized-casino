import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import dotenv from "dotenv";

dotenv.config();

const { POLYGON_API_KEY, PRIVATE_KEY } = process.env;

const config: HardhatUserConfig = {
  solidity: "0.8.24",
  networks: {
    amoy: {
      url: `https://polygon-amoy.g.alchemy.com/v2/${POLYGON_API_KEY!}`,
      accounts: [PRIVATE_KEY!],
    },
    sepolia: {
      url: `https://eth-sepolia.g.alchemy.com/v2/${POLYGON_API_KEY!}`,
      accounts: [PRIVATE_KEY!],
    },
  },
};

export default config;
