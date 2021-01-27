// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.8.0;

import {DelegationDataTypes} from "./DelegationDataTypes.sol";

/**
 * @dev -------------------------- TODO ---------------------------------
 * This library is analogous to Aave's `ReserveLogic`. Implements the logic
 * to update a delegation's state.
 * ----------------------------------------------------------------------
 */
library DelegationLogic {
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
        uint256 debt // debt this borrower owes to the delegator
    );

    /**
     * @dev Emitted when the state of a delegation is updated.
     * @param asset
     * @param delegator
     * @param delegate
     * @param creditLine
     * @param debt The **NEW** debt balance of the borrower that is now owed
     */
    event DelegationDataUpdated(
        address indexed asset,
        address indexed delegator,
        address delegate, // address of borrower with an uncollateralized loan
        uint256 creditLine, // limit of total debt
        uint256 debt // debt this borrower owes to the delegator
    );

    /**
     * @dev Initializes a delegation by adding a borrower. Call this function
     *      **AFTER** a delegator has approved a borrower.
     * @param _delegator The address of the creditor.
     * @param _delegate The address of borrower with an uncollateralized loan
     * @param _creditLine The bororwer's limit of total debt
     * @param _asset The address of the asset used in the delegation
     */
    function init(
        _delegator,
        _delegate,
        _creditLine,
        _asset
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

        emit DelegationDataCreated(
            delegation.asset,
            delegation.delegate,
            delegation.creditLine,
            delegation.debt,
            delegation.isApproved
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
