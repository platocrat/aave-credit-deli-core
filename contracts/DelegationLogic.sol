// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.8.1;

import {DelegationDataTypes} from "./DelegationDataTypes.sol";
import {CreditDeliStorage} from "./CreditDeliStorage.sol";

/**
 * @dev
 * This library is analogous to Aave's `ReserveLogic`. Implements the logic
 * to update a delegation's state.
 */
library DelegationLogic is CreditDeliStorage {
    using DelegationLogic for DelegationDataTypes.DelegationData;

    /**
     * @dev Emitted when a delegation is created.
     * @param asset The address of the asset used in the delegation.
     * @param delegator The address of the creditor.
     * @param delegate The address of the borrower.
     * @param creditLine The amount of credit delegated to the borrower.
     * @param debt The amount of credit used by the borrower that is now owed.
     */
    event DelegationDataCreated(
        address indexed asset,
        address indexed delegator,
        address delegate, // address of borrower with an uncollateralized loan
        uint256 creditLine, // limit of total debt
        uint256 debt, // debt this borrower owes to the delegator
        bool isApproved, // Does this delegation have an approved borrower?
        bool hasFullyRepayed, // Has the borrower repayed their loan?
        bool hasWithdrawn // Has the delegator withdrawn their deposit?
    );

    /**
     * @dev Emitted when the state of a delegation is updated.
     * @param asset The address of the asset used in the delegation.
     * @param delegator The address of the creditor.
     * @param delegate The address of the borrower.
     * @param creditLine The amount of credit delegated to the borrower.
     * @param debt The **NEW** debt balance of the borrower that is now owed
     */
    event DelegationDataUpdated(
        address indexed asset,
        address indexed delegator,
        address delegate, // address of borrower with an uncollateralized loan
        uint256 creditLine, // limit of total debt
        uint256 debt, // **NEW** debt balance of the borrower that is now owed
        bool isApproved, // Does this delegation have an approved borrower?
        bool hasFullyRepayed, // Has the borrower repayed their loan?
        bool hasWithdrawn // Has the delegator withdrawn their deposit?
    );

    /**
     * @dev Initializes a delegation by adding a borrower. Call this function
     *      **AFTER** a delegator has approved a borrower.
     * @param _asset The address of the asset used in the delegation
     * @param _delegator The address of the creditor.
     * @param _delegate The address of borrower with an uncollateralized loan
     * @param _creditLine The bororwer's limit of total debt
     */
    function init(
        address _asset,
        address _delegator,
        address _delegate,
        uint256 _creditLine
    ) external {
        // Initialize a delegation object.
        DelegationDataTypes.DelegationData storage delegation =
            _delegations[_delegator];

        delegation.asset = _asset;
        // Set the borrower address to the `delegate` field of the object.
        delegation.delegate = _delegate;
        delegation.creditLine = _creditLine;
        delegation.debt = 0;
        delegation.isApproved = true;
        delegation.hasFullyRepayed = false;
        delegation.hasWithdrawn = false;

        emit DelegationDataCreated(
            delegation.asset,
            _delegator,
            delegation.delegate,
            delegation.creditLine,
            delegation.debt,
            delegation.isApproved,
            delegation.hasFullyRepayed,
            delegation.hasWithdrawn
        );
    }

    /**
     * @dev Add the debt amount for this delegation.
     * @param _delegator The address of the creditor.
     * @param _amountToBorrow The debt of the delegate is borrowing.
     */
    function addDebt(address _delegator, uint256 _amountToBorrow) external {
        // Get the delegation for this delegator.
        DelegationDataTypes.DelegationData storage delegation =
            _delegations[_delegator];

        // Set the borrower address to the `delegate` field of the object.
        delegation.debt = _amountToBorrow;

        emit DelegationDataUpdated(
            delegation.asset,
            _delegator,
            delegation.delegate,
            delegation.creditLine,
            delegation.debt,
            delegation.isApproved,
            delegation.hasFullyRepayed,
            delegation.hasWithdrawn
        );
    }

    /**
     * @dev Add whether the delegation has been repayed in full.
     * @param _delegator The address of the creditor.
     * @param _repayAmount The amount of debt to be repayed.
     */
    function addRepayment(address _delegator, uint256 _repayAmount) external {
        // Get the delegation for this delegator.
        DelegationDataTypes.DelegationData storage delegation =
            _delegations[_delegator];

        // Set debt owed to new balance.
        delegation.debt = delegation.debt - _repayAmount;

        if (delegation.hasFullyRepayed == 0) delegation.hasFullyRepayed == true;

        emit DelegationDataUpdated(
            delegation.asset,
            _delegator,
            delegation.delegate,
            delegation.creditLine,
            delegation.debt,
            delegation.isApproved,
            delegation.hasFullyRepayed,
            delegation.hasWithdrawn
        );
    }

    /**
     * @dev Add whether the deposit for the delegation has been withdrawn.
     * @param _delegator The address of the creditor.
     */
    function addWithdrawal(address _delegator) external {
        // Get the delegation for this delegator.
        DelegationDataTypes.DelegationData storage delegation =
            _delegations[_delegator];

        delegation.hasWithdrawn = true;

        emit DelegationDataUpdated(
            delegation.asset,
            _delegator,
            delegation.delegate,
            delegation.creditLine,
            delegation.debt,
            delegation.isApproved,
            delegation.hasFullyRepayed,
            delegation.hasWithdrawn
        );
    }

    /**
     * @dev -------------------------- TODO ---------------------------------
     * Allow a function caller to view all debt owed to one delegator.
     * ----------------------------------------------------------------------
     */
    // function getBorrowerDebtOwedToDelegator(address _delegator)
    //     public
    //     view
    // // address _delegate
    // {
    //     /** @dev This may be costly */
    //     for (uint256 i = 0; i < Creditors[_delegator].length; i++) {
    //         require(
    //             Creditors[_delegator][i].exists,
    //             "This delegation does not yet exist!"
    //         );

    //         if (Creditors[_delegator][i].delegate == _delegate)
    //             return Creditors[_delegator][i].debt;
    //     }
    // }
}
