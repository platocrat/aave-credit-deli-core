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
 * @dev -------------------------------- TODO ----------------------------------
 * This example supports stable interest rate borrows.
 * -----------------------------------------------------------------------------
 * @dev -------------------------------- TODO ----------------------------------
 * It is not production ready (!). User permissions and user accounting of loans should be implemented.
 * See @dev comments
 * -----------------------------------------------------------------------------
 */

contract AaveCreditDelegationV2 {
    using SafeERC20 for IERC20;

    // ---------- State variables ----------
    address delegator;
    bool canPullFundsFromCaller;
    // Used to track approved borrowers/delegatees addresses
    mapping(address => bool) approvedToBorrow;
    address delegatee;
    // Used to select a delegatee to repay an uncollateralized loan
    address[] delegatees;
    /**
     * @dev -------------------------- TODO ---------------------------------
     * Used to track allowances (loan amounts) for each borrower/delegatee
     * ----------------------------------------------------------------------
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
     * Sets `canPullFundsFromCaller`. This would be called by the delegator.
     * @param _canPullFundsFromCaller Whether to pull the funds from the caller,
     * or use funds sent to this contract.
     */
    function setCanPullFundsFromCaller(bool _canPullFundsFromCaller) public {
        canPullFundsFromCaller = _canPullFundsFromCaller;
    }

    /**
     * Deposits collateral into the Aave, to enable credit delegation.
     * @notice User must have approved this contract to pull funds with a call
     * to the `setCanPullFundsFromCaller()` function above.
     * @param _asset The asset to be deposited as collateral.
     * @param _depositAmount The amount to be deposited as collateral.
     */
    function depositCollateral(address _asset, uint256 _depositAmount) public {
        // Ensure that this function is only called by the delegator.
        require(
            msg.sender == delegator,
            "Only the delegator can deposit collateral!"
        );

        // `canPull` is a boolean value is set by calling `setCanPullFundsFromCaller()`
        if (canPullFundsFromCaller) {
            IERC20(_asset).safeTransferFrom(
                msg.sender,
                address(this),
                _depositAmount
            );
        }

        // Approve Aave lending pool for deposit, then deposit `_depositAmount`
        IERC20(_asset).safeApprove(address(lendingPool), _depositAmount);
        lendingPool.deposit(_asset, _depositAmount, address(this), 0);
    }

    /**
     * Approves the borrower to take an uncollaterised loan.
     * @param _borrower The borrower of the funds (i.e. delgatee).
     * @param _borrowAmount The amount the borrower is allowed to borrow (i.e.
     * their line of credit).
     * @param _asset The asset they are allowed to borrow.
     */
    function approveBorrower(
        address _borrower,
        uint256 _borrowAmount,
        address _asset
    ) public {
        // Only the delegator should be able to approve borrowers!
        require(
            msg.sender == delegator,
            "Only the delegator (contract creator) can approve borrowers!"
        );

        delegatee = _borrower;

        /**
         * @dev -------------------------- TODO --------------------------------
         * MUST CHECK FOR WHETHER STABLE OR VARIABLE TOKEN
         * ---------------------------------------------------------------------
         */
        (, address stableDebtTokenAddress, ) =
            dataProvider.getReserveTokensAddresses(_asset);
        IStableDebtToken(stableDebtTokenAddress).approveDelegation(
            _borrower,
            _borrowAmount
        );

        // Track approved borrowers
        approvedToBorrow[_borrower] = true;
        // Used t delegatee to repay uncollateralized loan in `repayBorrower()`
        delegatees.push(_borrower);
    }

    // /**
    //  * Repay an uncollaterised loan (for use by approved borrowers). Approved
    //  * borrowers must have approved this contract, a priori, with an allowance
    //  * to transfer the tokens.
    //  * @param _repayAmount The amount to repay.
    //  * @param _asset The asset to be repaid.
    //  *
    //  * @dev -------------------------- TODO ------------------------------------
    //  * User calling this function must have approved this contract with an
    //  * allowance to transfer the tokens.
    //  * -------------------------------------------------------------------------
    //  *
    //  * @dev -------------------------- TODO ------------------------------------
    //  * You should keep internal accounting of borrowers, if your contract
    //  * will have multiple borrowers.
    //  * -------------------------------------------------------------------------
    //  */
    // function repayBorrower(uint256 _repayAmount, address _asset) public {
    //     require(
    //         approvedToBorrow[msg.sender] == true,
    //         "Only approved borrowers can repay an uncollateralized loan!"
    //     );
    //     /**
    //      * @dev -------------------------- TODO ------------------------------------
    //      * When is the `borrowerAllowances` set?
    //      */
    //     if (borrowerAllowances[msg.sender]) {}
    //     /**
    //      * @dev -------------------------- TODO ------------------------------------
    //      * Is this correct?
    //      */
    //     for (uint256 i = 0; i < delegatees.length; i++) {
    //         if (delegatees[i] == msg.sender) {
    //             IERC20(_asset).safeTransferFrom(
    //                 msg.sender,
    //                 address(this),
    //                 _repayAmount
    //             );
    //             IERC20(_asset).safeApprove(address(lendingPool), _repayAmount);
    //             lendingPool.repay(_asset, _repayAmount, 1, address(this));
    //         }
    //     }
    // }

    /**
     * Withdraw all of a collateral as the underlying asset, if no outstanding
     * loans delegated.
     * @param asset The underlying asset to withdraw.
     */
    function withdrawCollateral(address _asset) public {
        // Only the delegator should be able to withdraw their collateral!
        require(msg.sender == delegator);

        (address aTokenAddress, , ) =
            dataProvider.getReserveTokensAddresses(_asset);
        uint256 assetBalance = IERC20(aTokenAddress).balanceOf(address(this));

        lendingPool.withdraw(_asset, assetBalance, delegator);
    }
}
