// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.8.0;

import {DelegationDataTypes} from "./DelegationDataTypes.sol";

/**
 * @dev -------------------------- TODO ---------------------------------
 * This contract is analogous to Aave's `LendingPoolStorage`. Everything
 * other than core variable mappings and other storage variables must be
 * contained within the `DelegationLogic` contract.
 * ----------------------------------------------------------------------
 */
contract CreditDeliStorage {
    using DelegationLogic for DelegationDataTypes.DelegationData;

    // Records the approved delegatees of each delegator.
    mapping(address => DelegationData[]) internal Creditors;
}
