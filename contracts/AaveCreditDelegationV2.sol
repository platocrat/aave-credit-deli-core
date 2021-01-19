// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.8.0;

import {
    IERC20,
    ILendingPool,
    IProtocolDataProvider,
    IStableDebtToken
} from "./Interfaces.sol";
import {SafeERC20} from "./Libraries.sol";

/**
 * This is a proof of concept starter contract, showing how uncollaterised loans are possible
 * using Aave v2 credit delegation.
 * This example supports stable interest rate borrows.
 * It is not production ready (!). User permissions and user accounting of loans should be implemented.
 * See @dev comments
 */

contract AaveCreditDelegationV2 {
    using SafeERC20 for IERC20;

    // ---------- State variables ----------
    address delegator;
    bool canPull;
    // Used to track approved borrowers/delegatees addresses
    mapping(address => bool) approvedToBorrow;
    // Used to select a delegatee to repay an uncollateralized loan
    address[] delegatees;
    /**
     * @dev -------------------------- TODO ------------------------------------
     */
    mapping(address => mapping(address => uint256)) private borrowerAllowances;

    // CHANGE KOVAN ADDRESSES TO MAINNET ADDRESSES
    ILendingPool constant lendingPool =
        ILendingPool(address(0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9)); // Mainnet
    IProtocolDataProvider constant dataProvider =
        IProtocolDataProvider(
            address(0x057835Ad21a177dbdd3090bB1CAE03EaCF78Fc6d)
        ); // Mainnet

    constructor() public {
        delegator = msg.sender;
    }

    /**
     * Sets `canPull`.
     * This would be called by the delegator.
     * @param _canPull Whether to pull the funds from the caller, or use funds sent to this contract
     */
    function setCanPullFundsFromCaller(bool _canPull) public {
        canPull = _canPull;
    }

    /**
     * Deposits collateral into the Aave, to enable credit delegation
     * This would be called by the delegator.
     * @param asset The asset to be deposited as collateral
     * @param amount The amount to be deposited as collateral
     * @param canPull Whether to pull the funds from the caller, or use funds sent to this contract
     *  User must have approved this contract to pull funds if `canPull` = true
     */
    function depositCollateral(
        address asset,
        uint256 amount,
        bool canPull
    ) public {
        // This would be called by the delegator.

        if (canPull) {
            IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);
        }
        IERC20(asset).safeApprove(address(lendingPool), amount);
        lendingPool.deposit(asset, amount, address(this), 0);
    }

    /**
     * Approves the borrower to take an uncollaterised loan
     * @param borrower The borrower of the funds (i.e. delgatee)
     * @param amount The amount the borrower is allowed to borrow (i.e. their line of credit)
     * @param asset The asset they are allowed to borrow
     *
     * Add permissions to this call, e.g. only the delegator should be able to approve borrowers!
     */
    function approveBorrower(
        address borrower,
        uint256 amount,
        address asset
    ) public {
        // Only the delegator should be able to approve borrowers!
        require(
            msg.sender == delegator,
            "Only the delegator (contract creator) can approve borrowers!"
        );

        /** @dev MUST CHECK FOR WHETHER STABLE OR VARIABLE TOKEN */

        (, address stableDebtTokenAddress, ) =
            dataProvider.getReserveTokensAddresses(asset);
        IStableDebtToken(stableDebtTokenAddress).approveDelegation(
            borrower,
            amount
        );

        // Track approved borrowers
        approvedToBorrow[borrower] = true;
        // Used t delegatee to repay uncollateralized loan in `repayBorrower()`
        delegatees.push(borrower);
    }

    /**
     * Repay an uncollaterised loan (for use by approved borrowers). Approved
     * borrowers must have approved this contract, a priori, with an allowance
     * to transfer the tokens.
     * @param amount The amount to repay
     * @param asset The asset to be repaid
     *
     * User calling this function must have approved this contract with an allowance to transfer the tokens
     *
     * You should keep internal accounting of borrowers, if your contract will have multiple borrowers
     */
    function repayBorrower(uint256 amount, address asset) public {
        // require(
        //     approvedToBorrow[msg.sender] == true,
        //     "Only approved borrowers can repay an uncollateralized loan!"
        // );
        // /**
        //  * @dev -------------------------- TODO ------------------------------------
        //  * When is the `borrowerAllowances` set?
        //  */
        // if (borrowerAllowances[msg.sender]) {}
        // /**
        //  * @dev -------------------------- TODO ------------------------------------
        //  * Is this correct?
        //  */
        //  for (uint256 i = 0; i < delegatees.length; i++) {
        //     if (delegatees[i] == msg.sender) {
        //         IERC20(asset).safeTransferFrom(
        //             msg.sender,
        //             address(this),
        //             amount
        //         );
        //         IERC20(asset).safeApprove(address(lendingPool), amount);
        //         lendingPool.repay(asset, amount, 1, address(this));
        //     }
        // }
    }

    /**
     * Withdraw all of a collateral as the underlying asset, if no outstanding loans delegated
     * @param asset The underlying asset to withdraw
     *
     * Add permissions to this call, e.g. only the delegator should be able to withdraw the collateral!
     */
    function withdrawCollateral(address asset) public {
        // Only the delegator should be able to withdraw their collateral!
        require(msg.sender == delegator);

        (address aTokenAddress, , ) =
            dataProvider.getReserveTokensAddresses(asset);
        uint256 assetBalance = IERC20(aTokenAddress).balanceOf(address(this));
        lendingPool.withdraw(asset, assetBalance, delegator);
    }
}
