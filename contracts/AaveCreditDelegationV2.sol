// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.8.0;

import {
    IERC20,
    ILendingPool,
    IProtocolDataProvider,
    IStableDebtToken
} from "./Interfaces.sol";
import {SafeERC20} from "./Libraries.sol";

// ~~~~~~~~~~~~~~~~~~~~~~~~  CD struct functions ~~~~~~~~~~~~~~~~~~~~~~~~~~~

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
        address _delegator,
        address _delegatee,
        address _debt
    ) public returns (bool success) {
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
    IMCreditDelegation aaveCDData;

    using IMCreditDeli for IMCreditDelegation;
    using SafeERC20 for IERC20;

    address contractOwner;

    constructor() public {
        contractOwner = msg.sender;
    }

    // ---------- State variables ----------
    bool canPullFundsFromCaller;
    // Track addresses of borrowers (delegatees)
    mapping(address => bool) isBorrower;
    // // Used to select a delegatee to repay an uncollateralized loan
    // address[] delegatees;

    /**
     * @dev -------------------------- TODO ---------------------------------
     * Used to track allowances (loan amounts) for each borrower/delegatee
     * ----------------------------------------------------------------------
     */
    // Records the amount (`uint256`) the delegatee (`address`) is
    // allowed to withdraw from the delegator's account (`address`).
    mapping(address => mapping(address => uint256)) private borrowerAllowances;

    /**
     * @dev Change these addresses to Mainnet addresses when testing with forked
     * networks in hardhat. Use Kovan when testing UI.
     */
    ILendingPool constant lendingPool =
        ILendingPool(address(0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9)); // Mainnet
    IProtocolDataProvider constant dataProvider =
        IProtocolDataProvider(
            address(0x057835Ad21a177dbdd3090bB1CAE03EaCF78Fc6d)
        ); // Mainnet

    // ~~~~~~~~~~~~~~~~~~~~~~  Core contract functions  ~~~~~~~~~~~~~~~~~~~~~~~~

    event Deposit(
        address indexed asset,
        address indexed user,
        uint256 depositAmount
    );

    event CreditApproval(
        address indexed delegator,
        address indexed delegatee,
        uint256 credit,
        address asset // address indexed asset
    );

    event Borrow(
        address indexed delegatee,
        address indexed delegator,
        address assetToBorrow, // address indexed assetToBorrow,
        uint256 amountToBorrow,
        uint256 interestRateMode
        // uint16 _referralCode
    );

    /**
     * Deposits collateral into Aave lending pool to enable credit delegation.
     * @notice User must have approved this contract to pull funds with a call
     *         to the `setCanPullFundsFromCaller()` function above.
     * @param _asset                  The asset to be deposited as collateral.
     * @param _depositAmount          The amount to be deposited as collateral.
     * @param _canPullFundsFromCaller Boolean value set by user on UI.
     */
    function depositCollateral(
        address _asset,
        uint256 _depositAmount,
        bool _canPullFundsFromCaller // Ensure that this value is set client-side
    ) public {
        // Ensure that this function is only called by the delegator.
        require(
            isBorrower[msg.sender] == false,
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

        // Fetch this event client-side
        emit Deposit(_asset, msg.sender, _depositAmount);
    }

    /**
     * Approves a borrower to take an uncollaterised loan.
     * @param _delegatee    The borrower of the funds.
     * @param _credit       The amount the borrower is allowed to borrow (i.e.
     *                      their line of credit).
     * @param _asset        The asset they are allowed to borrow.
     */
    function approveBorrower(
        address _delegatee,
        uint256 _credit,
        address _asset
    ) public {
        // Only a delegator should be able to approve borrowers!
        require(
            !isBorrower[msg.sender],
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
            _delegatee,
            _credit
        );

        // Track approved borrowers.
        isBorrower[_delegatee] = true;

        /**
         * @dev -------------------------- TODO --------------------------------
         * What to do with `success` boolean value?
         * ---------------------------------------------------------------------
         */
        // Used to select a delegatee to repay an uncollateralized loan in the
        // `repayBorrower()` function.
        aaveCDData.addBorrower(msg.sender, _delegatee, _debt);

        emit CreditApproval(msg.sender, _delegatee, _credit, _asset);
    }

    /**
     * @dev -------------------------- TODO ---------------------------------
     * Let a borrower borrow an amount that was lended to them from a delegator
     * ----------------------------------------------------------------------
     * @param _assetToBorrow         The address for the asset.
     * @param _amountToBorrowInWei   Require <= amount delegated to borrower.
     * @param _interestRateMode      Require == type of debt delegated token
     * @param _referralCode          If no referral code, == `0`
     * @param _delegator
     */
    function borrowFromAaveLendingPool(
        address _assetToBorrow,
        uint256 _amountToBorrow,
        uint256 _interestRateMode,
        uint16 _referralCode,
        address _delegator
    ) public {
        // Only a delegatee can call borrow from the Aave lending pool!
        require(
            isBorrower[msg.sender],
            "Only a delegatee can borrow from the Aave lending pool. \n Delegators cannot borrow!"
        );

        /**
         * @dev -------------------  TODO  -----------------------------
         * Need a better way to check that the address of `msg.sender`
         * exists as a delegatee in the mapping of `Creditors`.
         *
         * If the address of `msg.sender` exists in the mapping of`Creditors`,
         * set the `msg.sender` to `_delegatee`.
         * -------------------------------------------------------------
         */
        for (uint256 i = 0; i < Creditors.length; i++) {
            require(
                Creditors[msg.sender] == true,
                "A delegator has not yet approved you for credit!"
            );

            _delegatee = msg.sender;

            if (Creditors[_delegator][i].delegatee == _delegatee)
                return Creditors[_delegator][i].debt;
        }

        _delegator = delegator;

        lendingPool.borrow(
            _assetToBorrow,
            _amountToBorrow,
            _interestRateMode,
            _referralCode,
            _delegator
        );

        emit Borrow(
            _delegatee,
            _delegator,
            _assetToBorrow,
            _amountToBorrow,
            _interestRateMode
        );
    }

    /**
     * Repay an uncollaterised loan (for use by approved borrowers). Approved
     * borrowers must have approved this contract, a priori, with an allowance
     * to transfer the tokens.
     * @param _repayAmount The amount to repay.
     * @param _asset       The asset to be repaid.
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
            isBorrower[msg.sender] == true,
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
            !isBorrower[msg.sender],
            "Only a delegator should be able to withdraw their collateral!"
        );
        // Only if no outstanding loans delegated

        (address aTokenAddress, , ) =
            dataProvider.getReserveTokensAddresses(_asset);
        uint256 assetBalance = IERC20(aTokenAddress).balanceOf(address(this));

        lendingPool.withdraw(_asset, assetBalance, delegator);
    }
}
