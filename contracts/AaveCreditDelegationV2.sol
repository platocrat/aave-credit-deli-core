// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.8.0;

import {
    IERC20,
    ILendingPool,
    IProtocolDataProvider,
    IStableDebtToken
} from "./Interfaces.sol";
import {SafeERC20} from "./Libraries.sol";

// struct IndexValue {
//     uint256 keyIndex;
//     uint256 value;
// }

// struct KeyFlag {
//     uint256 key;
//     bool deleted;
// }

// struct itmap {
//     mapping(uint256 => IndexValue) data;
//     KeyFlag[] keys;
//     uint256 size;
// }

// // Iterate over this data structure as an alternative to iterating over a
// // mapping (you cannot iterate over mappings).
// library IterableMapping {
//     /**
//      * @dev Change the value of a key of the `data` struct-field of the `itmap`
//      * struct.
//      * ----------------------------------------------------------------------
//      */
//     function insert(
//         itmap storage _self,
//         uint256 _key, // `itmap` key
//         uint256 _value // `itmap` value
//     ) internal returns (bool replaced) {
//         uint256 keyIndex = _self.data[_key].keyIndex;
//         _self.data[_key].value = _value;

//         if (keyIndex > 0) {
//             return true;
//         } else {
//             keyIndex = _self.keys.length;

//             _self.keys.push();
//             _self.data[key].keyIndex = keyIndex + 1;
//             _self.keys[keyIndex].key = _key;
//             _self.size++;

//             return false;
//         }
//     }

//     function remove(itmap storage _self, uint256 _key)
//         internal
//         returns (bool success)
//     {
//         uint256 keyIndex = _self.data[_key].keyIndex;

//         // data does not exist for this key -- see `contains()` below for more
//         // details
//         if (keyIndex == 0) return false;

//         // delete key from `data` field of `itmap` struct
//         delete _self.data[_key];

//         _self.keys[keyIndex - 1].deleted = true; // mark deleted index as deleted
//         _self.size -= 1; // decrement size of `itmap` struct
//     }

//     function contains(itmap storage _self, uint _key) internal view returns (bool) {
//         return _self.data[_key].keyIndex > 0;
//     })
// }

/**
 * This is a proof of concept starter contract, showing how uncollaterised loans are possible
 * using Aave v2 credit delegation.
 * @dev -------------------------------- TODO ----------------------------------
 * This example supports stable interest rate borrows.
 * -----------------------------------------------------------------------------
 * @dev -------------------------------- TODO ----------------------------------
 * It is not production ready (!). User permissions and user accounting of loans should be implemented.
 * See @dev comments
 * -----------------------------------------------------------------------------
 */
contract AaveCreditDelegationV2 {
    using SafeERC20 for IERC20;

    // ---------- State variables ----------
    address contractOwner;
    address delegator;
    bool canPullFundsFromCaller;
    // Used to track approved borrowers/delegatees addresses
    mapping(address => bool) approvedToBorrow;
    // Used to select a delegatee to repay an uncollateralized loan
    address[] delegatees;
    /**
     * @dev -------------------------- TODO ---------------------------------
     * Used to track allowances (loan amounts) for each borrower/delegatee
     * ----------------------------------------------------------------------
     */
    // Records the amount (`uint256`) the delegatee (`address`) is
    // allowed to withdraw from the delegator's account (`address`).
    mapping(address => mapping(address => uint256)) private borrowerAllowances;

    /**
     * @dev -------------------------- TODO --------------------------------
     * Each delegator address is mapped to a list of addresses of delegatees
     * whom the delegator has approved with a delegated line of credit.
     *
     * in JavaScript:
     *     CreditDelegation = {
     *         delegator1: [ delegatee1, delegatee2, ... ],
     *         delegator2: [ delegatee1, delegatee2, ... ],
     *         .
     *         .
     *         .
     *         delegator_N: [ ..., delegatee_N ]
     *
     *     }
     * ---------------------------------------------------------------------
     */
    // Records the approved delegatees of each delegator.
    struct CreditDelegation {
        address delegator;
        address[] delegatees;
        // KEEP THIS STRUCT SIMPLE FOR NOW (`_debt` can later be added to both
        // `delegator` and `delegatee` in their own structs).
        // uint256 _debt;
    }

    mapping(address => CreditDelegation[]) Creditors;

    function addDelegator(
        address _delegator,
        address _delegatee,
        address,
        address _debt
    ) public returns (bool success) {
        Creditors memory currentEntry;

        currentEntry.delegator = _delegator;
        currentEntry.delegatees.push(_delegatee);

        Creditors[_delegator].push(currentEntry);

        return true;
    }

    // CHANGE KOVAN ADDRESSES TO MAINNET ADDRESSES
    ILendingPool constant lendingPool =
        ILendingPool(address(0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9)); // Mainnet
    IProtocolDataProvider constant dataProvider =
        IProtocolDataProvider(
            address(0x057835Ad21a177dbdd3090bB1CAE03EaCF78Fc6d)
        ); // Mainnet

    constructor() public {
        contractOwner = msg.sender;
    }

    /**
     * Sets `canPullFundsFromCaller`. This would be called by the delegator.
     * @param _canPullFundsFromCaller Whether to pull the funds from the caller,
     * or use funds sent to this contract.
     */
    function setCanPullFundsFromCaller(bool _canPullFundsFromCaller) public {
        canPullFundsFromCaller = _canPullFundsFromCaller;
    }

    /**
     * Deposits collateral into Aave lending pool to enable credit delegation.
     * @notice User must have approved this contract to pull funds with a call
     * to the `setCanPullFundsFromCaller()` function above.
     * @param _asset The asset to be deposited as collateral.
     * @param _depositAmount The amount to be deposited as collateral.
     */
    function depositCollateral(address _asset, uint256 _depositAmount) public {
        // Ensure that this function is only called by the delegator.
        require(
            approvedToBorrow[msg.sender] == false,
            "Only a delegator can deposit collateral!"
        );
        // Boolean value is set by calling `setCanPullFundsFromCaller()`
        require(
            canPullFundsFromCaller,
            "You must first allow this contract to pull froms from your wallet!"
        );

        IERC20(_asset).safeTransferFrom(
            msg.sender,
            address(this),
            _depositAmount
        );

        // Approve Aave lending pool for deposit, then deposit `_depositAmount`
        IERC20(_asset).safeApprove(address(lendingPool), _depositAmount);
        lendingPool.deposit(_asset, _depositAmount, address(this), 0);
    }

    /**
     * Approves a borrower to take an uncollaterised loan.
     * @param _borrower The borrower of the funds (i.e. delegatee).
     * @param _borrowAmount The amount the borrower is allowed to borrow (i.e.
     * their line of credit).
     * @param _asset The asset they are allowed to borrow.
     */
    function approveBorrower(
        address _borrower,
        uint256 _borrowAmount,
        address _asset
    ) public {
        // Only a delegator should be able to approve borrowers!
        require(
            !approvedToBorrow[msg.sender],
            "Only a delegator can approve borrowers. Delegators cannot borrow!"
        );

        /**
         * @dev -------------------------- TODO --------------------------------
         * MUST CHECK FOR WHETHER STABLE OR VARIABLE TOKEN
         * ---------------------------------------------------------------------
         */
        (, address stableDebtTokenAddress, ) =
            dataProvider.getReserveTokensAddresses(_asset);
        IStableDebtToken(stableDebtTokenAddress).approveDelegation(
            _borrower,
            _borrowAmount
        );

        // Track approved borrowers.
        approvedToBorrow[_borrower] = true;
        // Used to select a delegatee to repay an uncollateralized loan in the
        // `repayBorrower()` function.
        delegatees.push(_borrower);
    }

    /**
     * @dev -------------------------- TODO ---------------------------------
     * Let the borrower borrow an amount that was lended to them from the delegator
     * ----------------------------------------------------------------------
     * @param _assetToBorrow         The address for the asset.
     * @param _amountToBorrowInWei   Require <= amount delegated to borrower.
     * @param _interestRateMode      Require == type of debt delegated token
     * @param _referralCode          If no referral code, == `0`
     * @param _delegatorAddress
     */
    function borrowFromAaveLendingPool(
        address _assetToBorrow,
        uint256 _amountToBorrow,
        uint256 _interestRateMode,
        uint16 _referralCode,
        address _delegatorAddress
    ) public {
        // Only a delegatee can call borrow from the Aave lending pool!
        require(
            approvedToBorrow[msg.sender],
            "Only a delegatee can borrow from the Aave lending pool. \n Delegators cannot borrow!"
        );

        _delegatorAddress = delegator;

        lendingPool.borrow(
            _assetToBorrow,
            _amountToBorrow,
            _interestRateMode,
            _referralCode,
            _delegatorAddress
        );
    }

    /**
     * Repay an uncollaterised loan (for use by approved borrowers). Approved
     * borrowers must have approved this contract, a priori, with an allowance
     * to transfer the tokens.
     * @param _repayAmount The amount to repay.
     * @param _asset The asset to be repaid.
     *
     * @dev -------------------------- TODO ------------------------------------
     * User calling this function must have approved this contract with an
     * allowance to transfer the tokens.
     * -------------------------------------------------------------------------
     *
     * @dev -------------------------- TODO ------------------------------------
     * You should keep internal accounting of borrowers, if your contract
     * will have multiple borrowers.
     * -------------------------------------------------------------------------
     */
    function repayBorrower(uint256 _repayAmount, address _asset) public {
        require(
            approvedToBorrow[msg.sender] == true,
            "Only approved borrowers can repay an uncollateralized loan!"
        );
        /**
         * @dev -------------------------- TODO ------------------------------------
         * When is the `borrowerAllowances` set?
         */
        if (borrowerAllowances[msg.sender]) {}
        /**
         * @dev -------------------------- TODO ------------------------------------
         * Is this correct?
         */
        for (uint256 i = 0; i < delegatees.length; i++) {
            if (delegatees[i] == msg.sender) {
                IERC20(_asset).safeTransferFrom(
                    msg.sender,
                    address(this),
                    _repayAmount
                );
                IERC20(_asset).safeApprove(address(lendingPool), _repayAmount);
                lendingPool.repay(_asset, _repayAmount, 1, address(this));
            }
        }
    }

    /**
     * Withdraw all collateral of an underlying asset, only if no outstanding
     * loans delegated.
     * @param _asset The underlying asset to withdraw.
     */
    function withdrawCollateral(address _asset) public {
        // Only a delegator should be able to withdraw their collateral!
        require(
            !approvedToBorrow[msg.sender],
            "Only a delegator should be able to withdraw their collateral!"
        );
        // Only if no outstanding loans delegated

        (address aTokenAddress, , ) =
            dataProvider.getReserveTokensAddresses(_asset);
        uint256 assetBalance = IERC20(aTokenAddress).balanceOf(address(this));

        lendingPool.withdraw(_asset, assetBalance, delegator);
    }
}
