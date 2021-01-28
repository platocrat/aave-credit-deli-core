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
    delegate: string, // == approved borrower
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
     * credit to potential delegates.
     * 
     * SO, a delegator address need NOT to be instantiated at contract creation.
     * Instead, it should be passed in as an argument when calling ANY of the
     * contract's functions.
     * 
     * ~~~~~~~~~~~~~~~~~~~~  ARCHITECTURE SIGNIFICANCE  ~~~~~~~~~~~~~~~~~~~~
     * The above means that the UI must be designed to accept *any account*
     * addresses as values for the `delegator`, `delegate`, and `delegates`
     * as function arguments for the credit delegation contract.
     * ----------------------------------------------------------------------
     */
    // These accounts start with 5000000000000000000 DAI at initialization
    [delegator, delegate] = await hre.ethers.provider.listAccounts()

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
      // 1. Delegator approves this contract to pull funds from his/her account.
      setCanPullFundsFromCaller(true)

      // 2. Delegator then deposits collateral into Aave lending pool.
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
   * @notice PASSES
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
       * @dev Send 20,000 DAI from CompoundDai contract to CD contract address
       */
      await dai.transfer(
        aaveCreditDelegationV2.address,
        hre.ethers.utils.parseUnits('20000', 'wei')
      )
    })

    /** @notice PASSES */
    // Send 20,000 to CD contract
    it('contract should now hold 20,000 DAI, after sending DAI to contract', async () => {
      const balanceAfterReceivingDAI: BigNumber = await dai.balanceOf(aaveCreditDelegationV2.address)
      const diff: BigNumber = balanceAfterReceivingDAI.sub(balanceBefore)

      expect(diff.toString()).to.equal('20000')
    })

    /** @notice PASSES */
    it('contract should have 10,000 less DAI after depositing collateral', async () => {
      // 1. Delegator approves this contract to pull funds from his/her account
      setCanPullFundsFromCaller(false)

      // 2. Delegator then clicks `deposit` button
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
   * @notice PASSES
   */
  describe("after approving borrower for 50% of delegator's deposit amount", async () => {
    let balanceBefore: BigNumber,
      canPullFundsFromCaller: boolean,
      assetToBorrow: string, // address
      // Must be equal to or less than amount delegated.
      amountToBorrowInWei: BigNumber,
      // Must be of the same type as the debt token that is delegated, i.e. 
      // stable = 1, variable = 2.
      interestRateMode: number,
      // To be implemented later (used for early supportive projects to the Aave
      // ecosystem). If there is no referral code, use `0`.
      referralCode: number

    function setCanPullFundsFromCaller(_canPull: boolean) {
      canPullFundsFromCaller = _canPull
    }

    before(async () => {
      // 1. Delegator approves this contract to pull funds from his/her account.
      setCanPullFundsFromCaller(true)

      // 2. Delegator then deposits collateral into Aave lending pool.
      await aaveCreditDelegationV2.depositCollateral(
        daiAddress,
        depositAmount,
        canPullFundsFromCaller
      )

      /**
       * @dev Can only call higher-order variables and functions under child
       * `before()` statements!
       */
      const delegatorSigner: Signer = await hre.ethers.provider.getSigner(delegator)

      amountToBorrowInWei = hre.ethers.BigNumber.from(depositAmount * 0.5)

      // 3. Delegator approves the delegate for a line of credit,
      //    which is a percentage of the delegator's collateral deposit.
      await aaveCreditDelegationV2.connect(delegatorSigner).approveBorrower(
        // address of borrower
        delegate,
        // test borrowing of full `depositAmount` and varying amounts of it
        amountToBorrowInWei,
        // address of asset
        daiAddress
      )
    })

    /** @notice FAILS */
    // Borrowing 50% of the delegated credit amount.
    it("delegate should borrow 50% of delegator's deposit amount from lending pool", async () => {
      assetToBorrow = daiAddress,
        interestRateMode = 1,                      // using the DAI stablecoin
        referralCode = 0                           // no referral code

      const delegateSigner: Signer = await hre.ethers.provider.getSigner(delegate)

      /**
       * @TODO ------------------------------ TODO -------------------------------
       * Hardhat is saying that the Aave lending pool address is invalid:
       * 0x7d2768de32b0b80b7a3454c06bdac94a69ddc7a9
       * -------------------------------------------------------------------------
       */

      // 4. The delegate borrows against the Aave lending pool using the credit
      //    delegated to them by the delegator.
      await aaveCreditDelegationV2.connect(delegateSigner).borrow(
        assetToBorrow,
        amountToBorrowInWei,
        interestRateMode,
        referralCode,
        delegator
      )

      const balanceAfterBorrowing: BigNumber = await dai.balanceOf(delegate)
      const diff: BigNumber = balanceAfterBorrowing.sub(balanceBefore)

      expect(diff.toString()).to.eq(amountToBorrowInWei)
    })

    /** @todo ----------------------  TODO -------------------------------------  */
    // it('repay the borrower', async () => {
    //   await aaveCreditDelegationV2.repayBorrower()
    // })
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
  //       delegate,
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