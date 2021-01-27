// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.8.0;

import {DelegationDataTypes} from "./DelegationDataTypes.sol";
import {DelegationLogic} from "./DelegationLogic.sol";

/**
 * @dev This contract is analogous to Aave's `LendingPoolStorage`. Everything
 * other than core variable mappings and other storage variables must be
 * contained within `DelegationLogic.sol`.
 */
contract CreditDeliStorage {
    using DelegationLogic for DelegationDataTypes.DelegationData;

    /**
     * @dev --------------------------  TODO  ----------------------------------
     * is `DelegationDataTypes.DelegationData[]` the correct data structure or
     * do I need to use another mapping, or a different data structure to solve
     * how to keep track of each delegate per delegator?
     *
     * Liam Horne's advice from Discord,
     * "You may want `(delegator, delegate) => boolean` mapping.
     * Basically, a mapping of every possible edge on the graph to true or false
     * -------------------------------  TODO  ----------------------------------
     */
    // Records the approved delegatees of each delegator.
    mapping(address => DelegationDataTypes.DelegationData)
        internal _delegations;


    // List of available delegations, structured as a mapping for gas savings
    // reasons
    mapping(uint256 => address) internal _delegationsList;

    // uint256 internal _delegationsCount;
    // bool internal _paused;
}
