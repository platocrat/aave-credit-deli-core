// SPDX-License-Identifier: MIT
pragma solidity 0.8.1;

library DelegationDataTypes {
    struct DelegationData {
        address asset; // Address of the asset used in the delegation
        address delegate; // Address of borrower with an uncollateralized loan
        uint256 collateralDeposit; // Delegator's collateral deposit amount
        uint256 creditLine; // Bororwer's limit of total debt
        uint256 debt; // Amount this borrower owes to the delegator
        bool isApproved; // Does this delegation have an approved borrower?
        bool hasFullyRepayed; // Has the borrower repayed their loan?
        bool hasWithdrawn; // Has the delegator withdrawn their deposit?
        bool exists; // Does this delegation exist?
        uint256 createdAt; // When this delegation was created
        uint256 updatedAt; // When this delegation was updated
    }
}
