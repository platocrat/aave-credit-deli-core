/**
 * @TODO -----------------------------------------------------------------------
 * "Always code [CONCISELY, CLEARLY, and READABLY] as if the guy who ends up 
 * maintaining your code will be a violent psychopath who knows where you 
 * live." - John Woods
 *-----------------------------------------------------------------------------
 */
import fetch from 'node-fetch'
import { expect } from "chai"
import hre from 'hardhat'
import { Signer } from 'ethers'
import { BigNumber } from '@ethersproject/bignumber'
import { Contract } from '@ethersproject/contracts'
import { JsonRpcSigner } from '@ethersproject/providers'

import { Dai } from '../typechain/contracts/Dai'
import DaiArtifact from '../artifacts/contracts/dai.sol/Dai.json'
import { MintableERC20 } from '../typechain/contracts/MintableERC20'

const ETH_URL: string = 'https://api.coingecko.com/api/v3/simple/price?ids=ethereum&vs_currencies=usd'

// Used to later compute ether and wei amounts to the current price of usd.
async function getEtherPrice(_url: string) {
  const json: any = (await fetch(_url)).json()
  return json // access the nested keys in the object to get extract the price.
}

describe('AaveCreditDelegationV2', () => {
  let aaveCreditDelegationV2: Contract,
    depositorSigner: JsonRpcSigner,
    borrowerSigner: JsonRpcSigner,
    delegator: string, // == contract creator
    delegate: string, // == approved borrower
    contractOwner: string,
    dai: MintableERC20

  const depositAmount: number = 2_000 // in USD
  const daiAddress: string = '0x6b175474e89094c44da98b954eedeac495271d0f'
  const lendingPoolAddress: string = '0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9'

  before(async () => {
    // Prepare DAI contract interface for CD contract 
    const signer: JsonRpcSigner = await hre.ethers.provider.getSigner(0);

    [delegator, delegate, contractOwner] = await hre.ethers.provider.listAccounts()
    depositorSigner = await hre.ethers.provider.getSigner(delegator)
    borrowerSigner = await hre.ethers.provider.getSigner(delegate)

    signer.sendTransaction({
      to: delegator,
      value: hre.ethers.utils.parseEther('1')
    })

    await hre.network.provider.request({
      method: 'hardhat_impersonateAccount',
      params: [delegator]
    })

    dai = await hre.ethers.getContractAt(
      'MintableERC20',
      daiAddress
    ) as MintableERC20

    

    const aaveCreditDelegationV2Address: string = hre
      .ethers.utils.getContractAddress({
        from: delegator,
        nonce: (await hre.ethers.provider.getTransactionCount(delegator)) + 1
      })

    // Approve credit delegation contract for transfers later
    await dai.approve(aaveCreditDelegationV2Address, hre.ethers.utils.parseEther('100'))

    // Create CD contract
    const AaveCreditDelegationV2 = await hre.ethers.getContractFactory(
      'AaveCreditDelegationV2'
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
      delegateBalanceBefore: BigNumber,
      delegatorBalanceBefore: BigNumber,
      balanceBeforeInEther: string,
      delegateBalanceBeforeInEther: string,
      delegatorBalanceBeforeInEther: string,
      canPullFundsFromCaller: boolean,
      assetToBorrow: string, // address
      // Must be of the same type as the debt token that is delegated, i.e. 
      // stable = 1, variable = 2.
      interestRateMode: number,
      // To be implemented later (used for early supportive projects to the Aave
      // ecosystem). If there is no referral code, use `0`.
      referralCode: number,
      currentEthPriceInUSD: number,
      fiveEtherInUSD: number

    function setCanPullFundsFromCaller(_canPull: boolean) {
      canPullFundsFromCaller = _canPull
    }

    before(async () => {
      // Balances in wei
      balanceBefore = await dai.balanceOf(delegator)
      delegateBalanceBefore = await dai.balanceOf(delegate)
      delegatorBalanceBefore = await dai.balanceOf(delegator)
      // Balances in ether
      balanceBeforeInEther = hre
        .ethers.utils.formatUnits(balanceBefore, 'ether')
      delegateBalanceBeforeInEther = hre
        .ethers.utils.formatUnits(delegateBalanceBefore, 'ether')
      delegatorBalanceBeforeInEther = hre
        .ethers.utils.formatUnits(delegatorBalanceBefore, 'ether')

      // Prices
      currentEthPriceInUSD = (await getEtherPrice(ETH_URL)).ethereum.usd
      fiveEtherInUSD = 5.0 * currentEthPriceInUSD
    })

    /** @notice PASSES */
    it('delegator should hold 5.0 ether worth of DAI before deposit', async () => {
      const balanceInUSD: number =
        parseFloat(balanceBeforeInEther) * currentEthPriceInUSD

      expect(balanceInUSD).to.eq(fiveEtherInUSD)
    })

    /** @notice PASSES */
    it('delegator should have 2,000 less DAI after depositing collateral', async () => {
      // 1. Delegator approves this contract to pull funds from his/her account.
      setCanPullFundsFromCaller(true)

      // Convert `depositAmount` to a value in wei
      const depositAmountInEther: number = depositAmount / currentEthPriceInUSD
      const depositAmountInWei: BigNumber = hre
        .ethers.utils.parseEther(depositAmountInEther.toString())

      // 2. Delegator then deposits collateral into Aave lending pool.
      await aaveCreditDelegationV2.connect(depositorSigner).depositCollateral(
        daiAddress,
        depositAmountInWei,
        canPullFundsFromCaller
      )

      const balanceAfter: BigNumber = await dai.balanceOf(delegator)
      const balanceAfterInEther: string = hre
        .ethers.utils.formatUnits(balanceAfter.toString(), 'ether')
      const diff: number =
        parseFloat(balanceBeforeInEther) - parseFloat(balanceAfterInEther)

      expect(diff.toFixed(7)).to.equal(depositAmountInEther.toFixed(7))
    })

    /** @notice FAILS */
    // Borrowing 50% of the delegated credit amount.
    it("delegate should borrow 50% of delegator's deposit amount from lending pool", async () => {
      assetToBorrow = daiAddress,
        // using the DAI stablecoin
        interestRateMode = 1,
        referralCode = 0                           // no referral code

      // Borrow amount must be <= amount delegated (1,000 DAI <= 2,000 DAI)
      const depositAmountInEther: number =
        (depositAmount * 0.5) / currentEthPriceInUSD
      const amountToBorrowInWei: BigNumber = hre
        .ethers.utils.parseEther(depositAmountInEther.toString())

      console.log("Amount to borrow in wei: ", amountToBorrowInWei.toString())
      console.log("Delegate balance of DAI before: ", (await dai.balanceOf(delegate)).toString())

      // 1. Delegator approves the delegate for a line of credit,
      //    which is a percentage of the delegator's collateral deposit.
      await aaveCreditDelegationV2.connect(depositorSigner).approveBorrower(
        // address of borrower
        delegate,
        // test borrowing of full `depositAmount` and varying amounts of it
        amountToBorrowInWei,
        // address of asset
        daiAddress
      )

      // 2. The delegate borrows against the Aave lending pool using the credit
      //    delegated to them by the delegator.
      /**
       * @TODO -------------------------- TODO ---------------------------------
       * Borrow function is called but delegate receives nothing after calling
       * borrow 
       * ----------------------------------------------------------------------
       */
      await aaveCreditDelegationV2.connect(borrowerSigner).borrow(
        assetToBorrow,
        amountToBorrowInWei,
        interestRateMode,
        referralCode,
        delegator
      )

      console.log("Delegate balance of DAI after: ", (await dai.balanceOf(delegate)).toString())

      const delegateBalanceAfterBorrowing: BigNumber = await dai
        .balanceOf(delegate)
      const diff: BigNumber = delegateBalanceAfterBorrowing
        .sub(delegateBalanceBefore)

      expect(diff.toString()).to.eq(amountToBorrowInWei)
    })

    /** @todo ----------------------  TODO ------------------------------------- */
    // it('repay the borrower', async () => {
    //   await aaveCreditDelegationV2.repayBorrower()
    // })
  })

  /** 
   * @dev Test when the delegator sets `canPull` to `false`
   * @notice PASSES
   */
  describe("deposit collateral with contract's funds", async () => {
    let balanceBefore: BigNumber,
      delegateBalanceBefore: BigNumber,
      balanceBeforeInEther: string,
      delegateBalanceBeforeInEther: string,
      canPullFundsFromCaller: boolean,
      assetToBorrow: string, // address
      // Must be equal to or less than amount delegated.
      amountToBorrowInWei: BigNumber,
      // Must be of the same type as the debt token that is delegated, i.e. 
      // stable = 1, variable = 2.
      interestRateMode: number,
      // To be implemented later (used for early supportive projects to the Aave
      // ecosystem). If there is no referral code, use `0`.
      referralCode: number,
      currentEthPriceInUSD: number,
      fiveEtherInUSD: number

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

      // Balances in ether
      delegateBalanceBefore = await dai.balanceOf(delegate)
      // Balances in wei
      balanceBeforeInEther = hre
        .ethers.utils.formatUnits(balanceBefore, 'ether')
      delegateBalanceBeforeInEther = hre
        .ethers.utils.formatUnits(delegateBalanceBefore, 'ether')

      // Prices
      currentEthPriceInUSD = (await getEtherPrice(ETH_URL)).ethereum.usd
      fiveEtherInUSD = 5.0 * currentEthPriceInUSD

      await dai.transfer(
        aaveCreditDelegationV2.address,
        /**
         * @TODO ------------------------------ TODO -------------------------------
         * Need to test lower deposit and borrow amounts!
         * -------------------------------------------------------------------------
         */
        hre.ethers.utils.parseEther('1')
      )
    })

    /** @notice PASSES */
    // Send 20,000 to CD contract
    it('contract should now hold 5.0 ether worth of DAI, after sending DAI to contract', async () => {
      // const balanceAfterReceivingDAI: BigNumber = await dai.balanceOf(aaveCreditDelegationV2.address)
      // const diff: BigNumber = balanceAfterReceivingDAI.sub(balanceBefore)

      // expect(diff.toString()).to.equal('20000')
    })

    /** @notice PASSES */
    it('contract should have 2,000 less DAI after depositing collateral', async () => {
      // // 1. Delegator denies this contract to pull funds from his/her account,
      // //    in effect, telling the contract to use funds held within it.
      // setCanPullFundsFromCaller(false)

      // // Convert `depositAmount` to a value in wei
      // const depositAmountInEther: number = depositAmount / currentEthPriceInUSD
      // const depositAmountInWei: BigNumber = hre
      //   .ethers.utils.parseEther(depositAmountInEther.toString())

      // // 2. Delegator then clicks `deposit` button
      // await aaveCreditDelegationV2.connect(depositorSigner).depositCollateral(
      //   daiAddress,
      //   depositAmountInWei,
      //   canPullFundsFromCaller
      // )

      // const balanceAfter: BigNumber = await dai.balanceOf(delegator)
      // const balanceAfterInEther: string = hre
      //   .ethers.utils.formatUnits(balanceAfter.toString(), 'ether')
      // const diff: number =
      //   parseFloat(balanceBeforeInEther) - parseFloat(balanceAfterInEther)

      // expect(diff.toFixed(7)).to.equal(depositAmountInEther.toFixed(7))
    })
  })
})