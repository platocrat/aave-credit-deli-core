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
    /**
     * @dev Emitted when the state of a delegation is updated
     * @param asset The address of the asset used in the delegation
     * @param delegator The address of the creditor
     * @param delegate The address of the borrower
     * @param creditLine The amount of credit delegated to the borrower
     * @param debt The amount of credit used by the borrower that is now owed
     */
    event DelegationDataUpdated(
        address indexed asset,
        address indexed delegator,
        address delegate, // address of borrower with an uncollateralized loan
        uint256 creditLine, // limit of total debt
        uint256 debt // debt this borrower owes to the delegator
    );

    using DelegationLogic for DelegationDataTypes.DelegationData;

    /**
     * @dev Initializes a delegation
     * @param _delegation The delegation object
     * @param _asset The address of the asset used in the delegation
     * @param _delegate The address of borrower with an uncollateralized loan
     * @param _creditLine The bororwer's limit of total debt
     */
    function init(
        DelegationDataTypes.DelegationData storage _delegation,
        address _asset,
        address _delegate,
        uint256 _creditLine
    ) external {
        _delegation.asset = _asset;
        _delegation.delegate = _delegate;
        _delegation.creditLine = _creditLine;
        _delegation.debt = 0;
    }

    /**
     * @dev Call this function **after** when the delegator approves a borrower
     * @param delegation The delegation object
     * @return boolean of whether adding the borrower was successful or not
     */
    function addBorrower(DelegationDataTypes.DelegationData storage delegation)
        internal
        returns (bool success)
    {
        Creditors memory currentDelegation;

        currentDelegation.delegate = _delegate;
        currentDelegation.debt = _debt;

        Creditors[_delegator].push(currentDelegation);

        emit DelegationDataUpdated(
            asset,
            delegator,
            delegate,
            creditLine,
            debt
        );

        return true;
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
