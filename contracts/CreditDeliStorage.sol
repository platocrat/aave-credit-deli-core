// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.8.0;

import {DelegationDataTypes} from "./DelegationDataTypes.sol";

/**
 * @dev This contract is analogous to Aave's `LendingPoolStorage`. Everything
 * other than core variable mappings and other storage variables must be
 * contained within `DelegationLogic.sol`.
 */
contract CreditDeliStorage {
    using DelegationLogic for DelegationDataTypes.DelegationData;

    // Records the approved delegatees of each delegator.
    mapping(address => DelegationDataTypes.DelegationData)
        internal _delegations;
    // List of available delegations, structured as a mapping for gas savings
    // reasons
    mapping(uint256 => address) internal _delegationsList;

    // uint256 internal _delegationsCount;
    // bool internal _paused;
}
