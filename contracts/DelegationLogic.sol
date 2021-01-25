// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.8.0;

import "./DelegationDataTypes.sol";

/**
 * @dev -------------------------- TODO ---------------------------------
 * This library is analogous to Aave's `ReserveLogic`. Implements the logic
 * to update a delegation's state.
 * ----------------------------------------------------------------------
 */
library DelegationLogic {
    using DelegationLogic for DelegationDataTypes.DelegationData;

    /**
     * @dev Call this function **after** when the delegator approves a borrower
     */
    function addBorrower(
        IMCreditDelegation storage _self,
        address _delegator,
        address _delegatee,
        address _debt
    ) internal returns (bool success) {
        // uint256 keyIndex = _self.Creditors[_delegator].

        Creditors memory currentDelegation;

        currentDelegation.exists = true;
        currentDelegation.delegatee = _delegatee;
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
    // // address _delegatee
    // {
    //     /** @dev This may be costly */
    //     for (uint256 i = 0; i < Creditors[_delegator].length; i++) {
    //         require(
    //             Creditors[_delegator][i].exists,
    //             "This delegation does not yet exist!"
    //         );

    //         if (Creditors[_delegator][i].delegatee == _delegatee)
    //             return Creditors[_delegator][i].debt;
    //     }
    // }
}
