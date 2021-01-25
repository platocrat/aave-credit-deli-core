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
    event DelegationDataUpdated(
        address indexed delegator,
        address indexed delegate, // address of borrower with an uncollateralized loan
        uint256 creditLine, // limit of total debt
        uint256 debt, // debt this borrower owes to the delegator
        bool exists // does this credit delegation exist?
    );

    using DelegationLogic for DelegationDataTypes.DelegationData;

    /**
     * @dev Call this function **after** when the delegator approves a borrower
     */
    function addBorrower(
        // IMCreditDelegation storage _self,
        address _delegator,
        address _delegate,
        address _debt
    ) internal returns (bool success) {
        // uint256 keyIndex = _self.Creditors[_delegator].

        Creditors memory currentDelegation;

        currentDelegation.exists = true;
        currentDelegation.delegate = _delegate;
        currentDelegation.debt = _debt;

        Creditors[_delegator].push(currentDelegation);

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