// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.8.0;

/**
 * @dev "IM" stands for "IterableMapping"
 * @dev -------------------------- TODO ---------------------------------
 * This library is analogous to Aave's `DataTypes`. Everything other than the
 * `struct`s and `enum`s to be contained within the `CreditDeliStorage`
 * contract.
 * ----------------------------------------------------------------------
 */
library DelegationDataTypes {
    /**
     * @dev Structs taken from IterableMapping example in Solidity docs:
     * https://docs.soliditylang.org/en/v0.8.0/types.html#operators-involving-lvalues
     */
    // struct KeyFlag {
    //     uint256 key;
    //     bool isDelegator;
    // }

    struct DelegationData {
        address delegate; // address of borrower with an uncollateralized loan
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
    // struct IMCreditDelegation {
    //     // Records the approved delegates of each delegator.
    //     mapping(address => CreditDelegation[]) Creditors;
    //     KeyFlag[] keys;
    //     uint256 size;
    // }

    // enum InterestRateMode {NONE, STABLE, VARIABLE};
}
