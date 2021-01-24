// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.8.0;

/**
 * @dev Structs taken from IterableMapping example in Solidity docs:
 * https://docs.soliditylang.org/en/v0.8.0/types.html#operators-involving-lvalues
 */
struct KeyFlag {
    uint256 key;
    bool isDelegator;
}

struct CreditDelegation {
    address delegatee; // address of borrower with an uncollateralized loan
    uint256 creditLine; // limit of total debt
    uint256 debt; // debt this borrower owes to the delegator
    bool exists; // does this credit delegation exist?
}

/**
 * @dev -------------------------- TODO ---------------------------------
 * Add the proper functions for this CD iterable mapping under its respective
 * library
 * ----------------------------------------------------------------------
 */
struct IMCreditDelegation {
    // Records the approved delegatees of each delegator.
    mapping(address => CreditDelegation[]) Creditors;
    KeyFlag[] keys;
    uint256 size;
}

/**
 * @dev "IM" stands for "IterableMapping"
 */
library IMCreditDeli {
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
