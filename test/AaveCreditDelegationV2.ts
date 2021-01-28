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

import DaiArtifact from '../artifacts/contracts/dai.sol/Dai.json'

describe('AaveCreditDelegationV2', () => {
  let aaveCreditDelegationV2: Contract,
    depositorSigner: JsonRpcSigner,
    delegator: string, // == contract creator
    delegatee: string,
    approvedToBorrow: boolean[],
    dai: Dai

  const depositAmount: number = 10_000
  const daiAddress: string = '0x6b175474e89094c44da98b954eedeac495271d0f'

  const lendingPoolAddress: string = '0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9'

  before(async () => {
    // Prepare DAI contract interface for CD contract 
    const signer: JsonRpcSigner = await hre.ethers.provider.getSigner(0);

    /**
     * @todo -------------------------- TODO ---------------------------------
     * NOTE: delegator address is instantiated when contract at creation.
     *
     * The goal of `AaveCreditDelegationV2.sol` is to be a generalized contract
     * that can be deployed once and used by any wishing delegators wanting to
     * deposit collateral into the Aave lending pool to then delegate their 
     * credit to potential delegatees.
     * 
     * SO, a delegator address need NOT to be instantiated at contract creation.
     * Instead, it should be passed in as an argument when calling ANY of the
     * contract's functions.
     * 
     * ~~~~~~~~~~~~~~~~~~~~  ARCHITECTURE SIGNIFICANCE  ~~~~~~~~~~~~~~~~~~~~
     * The above means that the UI must be designed to accept *any account*
     * addresses as values for the `delegator`, `delegatee`, and `delegatees`
     * as function arguments for the credit delegation contract.
     * ----------------------------------------------------------------------
     */
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
      'AaveCreditDelegationV2',
      depositorSigner
    )

    aaveCreditDelegationV2 = await AaveCreditDelegationV2.deploy()

    await aaveCreditDelegationV2.deployed()
  })

  /**
   * @dev 
   * Just for your knowledge the await method is fine to call. Since write 
   * methods return contract transactions unlike read methods which will
   * return balance for example after calling contract.balanceOf() we can 
   * ignore the await if we are not going to be unwapping the contract
   * transaction object returned in a promise.
   */

  /** @notice PASSES */
  describe("deposit collateral with delegator's funds", async () => {
    let balanceBefore: BigNumber,
      canPullFundsFromCaller: boolean

    function setCanPullFundsFromCaller(_canPull: boolean) {
      canPullFundsFromCaller = _canPull
    }

    before(async () => {
      balanceBefore = await dai.balanceOf(delegator)
    })

    /** @notice PASSES */
    // All accounts start with 5000000000000000000 DAI at initialization
    it('delegator should hold 5000000000000000000 DAI before deposit', async () => {
      expect(balanceBefore.toString()).to.equal('5000000000000000000')
    })

    /** @notice PASSES */
    it('delegator should have 10,000 less DAI after depositing collateral', async () => {
      // 1. User approves this contract to pull funds from his/her account.
      setCanPullFundsFromCaller(true)

      // 2. The same user then deposits collateral into Aave lending pool.
      await aaveCreditDelegationV2.depositCollateral(
        daiAddress,
        depositAmount,
        canPullFundsFromCaller
      )

      const balanceAfter: BigNumber = await dai.balanceOf(delegator)
      const diff: BigNumber = balanceBefore.sub(balanceAfter)

      expect(diff.toString()).to.equal("10000")
    })
  })

  /** 
   * @dev Test when the delegator sets `canPull` to `false`
   * @notice FAILS
   */
  describe("deposit collateral with contract's funds", async () => {
    let balanceBefore: BigNumber,
      canPullFundsFromCaller: boolean

    /**
     * @TODO ------------------------------ TODO -------------------------------
     * Add an easy radio switch directly above or next to the the `deposit` 
     * button (to deposit collateral) which disables the `deposit` button when
     * switched off, and enables deposits when switched on.
     * -------------------------------------------------------------------------
     */
    // This function is called by the UI when the delegator flips the radio 
    // switch, thus allowing for the UI to pull funds from their wallet and 
    // enabling the `deposit` button.
    function setCanPullFundsFromCaller(_canPull: boolean) {
      canPullFundsFromCaller = _canPull
    }

    before(async () => {
      balanceBefore = await dai.balanceOf(aaveCreditDelegationV2.address)

      /**
       * @dev Send 200 DAI from CompoundDai contract to CD contract address
       */
      await dai.transfer(
        aaveCreditDelegationV2.address,
        hre.ethers.utils.parseUnits('20000', 'wei')
      )
    })

    /** @notice PASSES */
    // Send 200 to CD contract
    it('delegator should now hold 2,000 DAI after sending DAI to contract', async () => {
      const balanceAfterReceivingDAI: BigNumber = await dai.balanceOf(aaveCreditDelegationV2.address)
      const diff: BigNumber = balanceAfterReceivingDAI.sub(balanceBefore)

      expect(diff.toString()).to.equal('20000')
    })

    /** @notice PASSES */
    it('contract should have 10,000 less DAI after depositing collateral', async () => {
      // 1. User approves this contract to pull funds from his/her account
      setCanPullFundsFromCaller(false)

      // 2. User then clicks `deposit` button
      await aaveCreditDelegationV2.depositCollateral(
        daiAddress,
        depositAmount,
        canPullFundsFromCaller
      )

      const balanceAfterDepositingCollateral: BigNumber = await dai.balanceOf(aaveCreditDelegationV2.address)
      const diff: BigNumber = balanceAfterDepositingCollateral.sub(balanceBefore)

      expect(diff.toString()).to.equal("10000")
    })
  })

  /** 
   * @dev Approving the delegation for the borrower to use the delegated credit.
   * @notice ----------------------  FAILS ------------------------------------- 
   */
  describe("after approving borrower for 50% of delegator's deposit amount", async () => {
    let balanceBefore: BigNumber,
      assetToBorrow: string, // address
      // Must be equal to or less than amount delegated.
      amountToBorrowInWei: BigNumber,
      // Must be of the same type as the debt token that is delegated, i.e. 
      // stable = 1, variable = 2.
      interestRateMode: number,
      // To be implemented later (used for early supportive projects to the Aave
      // ecosystem). If there is no referral code, use `0`.
      referralCode: number,
      delegatorAddress: string

    before(async () => {
      /**
       * @dev Can only call higher-order variables and functions under child
       * `before()` statements!
       */
      const ownerSigner: Signer = await hre.ethers.provider.getSigner(delegator)

      amountToBorrowInWei = hre.ethers.BigNumber.from(depositAmount * 0.5)

      /**
       * @todo -------------------------- TODO ---------------------------------
       * Let a borrower borrow an amount that was lended to them from the delegator
       * ----------------------------------------------------------------------
       */
      await aaveCreditDelegationV2.connect(ownerSigner).approveBorrower(
        // address of borrower
        delegatee,
        // test borrowing of full `depositAmount` and varying amounts of it
        amountToBorrowInWei,
        // address of asset
        daiAddress
      )
    })

    /** @notice FAILS */
    // Borrowing 50% of the delegated credit amount.
    it("delegatee should borrow 50% of delegator's deposit amount from lending pool", async () => {
      assetToBorrow = daiAddress,
        interestRateMode = 1,                      // using the DAI stablecoin
        referralCode = 0,                          // no referral code
        /**
         * @todo -------------------------- TODO ---------------------------------
         * NOTE: delegator address is instantiated when contract at creation.
         *
         * The goal of `AaveCreditDelegationV2.sol` is to be a generalized contract
         * that can be deployed once and used by any wishing delegators wanting to
         * deposit collateral into the Aave lending pool to then delegate their 
         * credit to potential delegatees.
         * 
         * SO, a delegator address need NOT to be instantiated at contract creation.
         * Instead, it should be passed in as an argument when calling ANY of the
         * contract's functions.
         * ----------------------------------------------------------------------
         */
        delegatorAddress = delegator

      // Borrow
      await aaveCreditDelegationV2.borrow(
        assetToBorrow,
        amountToBorrowInWei,
        interestRateMode,
        referralCode,
        delegatorAddress
      )

      const balanceAfterBorrowing: BigNumber = await dai.balanceOf(delegatee)
      const diff: BigNumber = balanceAfterBorrowing.sub(balanceBefore)

      expect(diff.toString()).to.eq(amountToBorrowInWei)
    })

    /** @todo ----------------------  TODO -------------------------------------  */
    it('repay the borrower', async () => {
      await aaveCreditDelegationV2.repayBorrower()
    })
  })

  // describe("after approving borrower for 100% of delegator's deposit amount", async () => {
  //   before(async () => {
  //     /**
  //      * @dev Can only call higher-order variables and functions under child
  //      * `before()` statements!
  //      */
  //     const ownerSigner = await hre.ethers.provider.getSigner(delegator)

  //     await aaveCreditDelegationV2.connect(ownerSigner).approveBorrower(
  //       // address borrower
  //       delegatee,
  //       // test borrowing of full `depositAmount` and varying amounts of it
  //       depositAmount,
  //       // address asset
  //       daiAddress
  //     )
  //   })

  //   it('repay the borrower', async () => {
  //     await aaveCreditDelegationV2.
  //   })
  // })
})