/**
 * @TODO -----------------------------------------------------------------------
 * "Always code [CONCISELY, CLEARLY, and READABLY] as if the guy who ends up 
 * maintaining your code will be a violent psychopath who knows where you 
 * live." - John Woods
 *-----------------------------------------------------------------------------
 */
import { expect } from "chai"
import hre from 'hardhat'
import { Signer } from 'ethers'
import { BigNumber } from '@ethersproject/bignumber'
import { Contract } from '@ethersproject/contracts'
import { JsonRpcSigner } from '@ethersproject/providers'
import { Dai } from '../typechain'

import DaiArtifact from '../artifacts/contracts/DAI.sol/DAI.json'

describe('AaveCreditDelegationV2', () => {
  let aaveCreditDelegationV2: Contract,
    depositorSigner: JsonRpcSigner,
    delegator: string, // == contract creator
    delegatee: string,
    approvedToBorrow: boolean[],
    dai: Dai

  const depositAmount = 100
  const daiAddress = '0x6b175474e89094c44da98b954eedeac495271d0f'
  const lendingPoolAddress = '0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9'

  before(async () => {
    // Prepare DAI contract interface for CD contract 
    const signer: JsonRpcSigner = await hre.ethers.provider.getSigner(0);

    // These accounts start with 5000000000000000000 DAI at initialization
    [delegator, delegatee] = await hre.ethers.provider.listAccounts()

    signer.sendTransaction({
      to: delegator,
      value: hre.ethers.utils.parseEther('1')
    })

    await hre.network.provider.request({
      method: 'hardhat_impersonateAccount',
      params: [delegator]
    })

    dai = await hre.ethers.getContractAt('IERC20', daiAddress) as Dai

    const aaveCreditDelegationV2Address: string = hre
      .ethers.utils.getContractAddress({
        from: delegator,
        nonce: (await hre.ethers.provider.getTransactionCount(delegator)) + 1
      })

    await dai.approve(aaveCreditDelegationV2Address, depositAmount)

    depositorSigner = await hre.ethers.provider.getSigner(delegator)

    // Create CD contract
    const AaveCreditDelegationV2 = await hre.ethers.getContractFactory(
      'aaveCreditDelegationV2',
      depositorSigner
    )

    aaveCreditDelegationV2 = await AaveCreditDelegationV2.deploy()

    await aaveCreditDelegationV2.deployed()

    /**
     * @dev 
     * Just for your knowledge the await method is fine to call. Since write 
     * methods return contract transactions unlike read methods which will
     * return balance for example after calling contract.balanceOf() we can 
     * ignore the await if we are not going to be unfwapping the contract
     * transaction object returned in a promise.
     */
  })


  /** 
   * @dev Test when the delegator sets `canPull` to `true`
   * @notice PASSES
   */
  describe("deposit collateral with delegator's funds", async () => {
    let balanceBefore: BigNumber

    const canPull: boolean = true

    before(async () => {
      balanceBefore = await dai.balanceOf(delegator)
    })

    // All accounts start with 5000000000000000000 DAI at initialization
    it('delegator should hold 5000000000000000000 DAI before deposit', async () => {
      expect(balanceBefore.toString()).to.equal('5000000000000000000')
    })

    it('delegator should have 100 less DAI after depositing collateral', async () => {
      await aaveCreditDelegationV2.setCanPullFundsFromCaller(canPull)
      await aaveCreditDelegationV2.depositCollateral(
        daiAddress,
        depositAmount,
        // User approves this contract to pull funds from his/her account
        canPull
      )

      const balanceAfter: BigNumber = await dai.balanceOf(delegator)
      const diff: BigNumber = balanceBefore.sub(balanceAfter)

      expect(diff.toString()).to.equal("100")
    })
  })

  /** 
   * @dev Test when the delegator sets `canPull` to `false`
   */
  describe("deposit collateral with contract's funds", async () => {
    let balanceBefore: BigNumber

    const canPull: boolean = false

    before(async () => {
      /**
       * @dev Send 200 DAI from CompoundDai contract to CD contract address
       */
      balanceBefore = await dai.balanceOf(aaveCreditDelegationV2.address)

      await dai.transfer(
        aaveCreditDelegationV2.address,
        hre.ethers.utils.parseUnits('200', 'wei')
      )
    })

    // Send 200 to CD contract
    it('delegator should now hold 200 DAI after sending DAI to contract', async () => {
      const balanceAfterReceivingDAI: BigNumber = await dai.balanceOf(aaveCreditDelegationV2.address)
      const diff: BigNumber = balanceAfterReceivingDAI.sub(balanceBefore)

      expect(diff.toString()).to.equal('200')
    })

    it('contract should have 100 less DAI after depositing collateral', async () => {
      await aaveCreditDelegationV2.setCanPullFundsFromCaller(canPull)
      await aaveCreditDelegationV2.depositCollateral(
        daiAddress,
        depositAmount,
        // User approves this contract to pull funds from his/her account
        canPull
      )

      const balanceAfterDepositingCollateral: BigNumber = await dai.balanceOf(aaveCreditDelegationV2.address)
      const diff: BigNumber = balanceAfterDepositingCollateral.sub(balanceBefore)

      expect(diff.toString()).to.equal("100")
    })
  })

  /** 
   * @dev Approving the delegation for the borrower to use the delegated credit
   */
  describe("after approving borrower for 50% of delegator's deposit amount", async () => {
    before(async () => {
      /**
       * @dev Can only call higher-order variables and functions under child
       * `before()` statements!
       */
      const ownerSigner = await hre.ethers.provider.getSigner(delegator)

      await aaveCreditDelegationV2.connect(ownerSigner).approveBorrower(
        // address borrower
        delegatee,
        // test borrowing of full `depositAmount` and varying amounts of it
        depositAmount * 0.5,
        // address asset
        daiAddress
      )
    })

    it('repay the borrower', async () => {
      await aaveCreditDelegationV2.
    })
  })
})