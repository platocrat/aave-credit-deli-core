// SPDX-License-Identifier: MIT
pragma solidity 0.8.1;

import {DelegationDataTypes} from "./DelegationDataTypes.sol";

contract CreditDeliStorage {
    using DelegationDataTypes for DelegationDataTypes.DelegationData;

    // Records the approved delegate of each delegator.
    mapping(address => DelegationDataTypes.DelegationData)
        internal _delegations;

    mapping(uint256 => address) internal _delegationsList;
}
