import { task } from 'hardhat/config'
import '@nomiclabs/hardhat-waffle'
import '@nomiclabs/hardhat-ethers'
import 'dotenv/config'

export default {
  networks: {
    hardhat: {
      forking: {
        url: process.env.MAINNET_FORKING_URL,
        blockNumber: 11395144
      }
    }
  },
  solidity: {
    version: '0.8.1',
    settings: {
      optimizer: {
        enabled: true,
        runs: 200
      }
    }
  }
}