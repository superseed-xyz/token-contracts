// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "./dependencies/openzeppelin/token/ERC20/utils/SafeERC20.sol";
import "./dependencies/openzeppelin/access/AccessControl.sol";
import "./dependencies/openzeppelin/utils/cryptography/MerkleProof.sol";
import "./dependencies/openzeppelin/utils/Pausable.sol";

/**
 * @title SuperSaleDeposit Contract
 * @notice This contract allows users to deposit USDC or USDT and purchase tokens in tiers with discounts and bonuses.
 *         The contract uses Merkle Proof for whitelisting users and SafeERC20 for token transfers.
 * @dev Access Control description:
 *      SuperAdmin [DEFAULT_ADMIN_ROLE]:
 *         - Can grant and revoke roles.
 *      Admin [ADMIN_ROLE]:
 *         - Can manage contract parameters setup like sale configuration and recipient of funds.
 *         - In exceptional scenarios like a security breach or unforeseen situations: Can intervene in the sale process
 * by pausing the contract.
 *      Operator [OPERATOR_ROLE]:
 *         - Can update the Merkle root for whitelist verification.
 * @dev Uses Merkle Proof for whitelisting users and SafeERC20 for token transfers.
 */
contract SuperSaleDeposit is AccessControl, Pausable {
    /*//////////////////////////////////////////////////////////////
                            LIBRARIES
    //////////////////////////////////////////////////////////////*/

    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                            STRUCTS & ENUMS
    //////////////////////////////////////////////////////////////*/

    // ============== Structs ==============
    /**
     * @notice Info about user deposit
     */
    struct UserDepositInfo {
        uint256 amountDeposited; // Total amount deposited by the user
        uint256 purchasedTokens; // Total tokens purchased by the user
    }

    /**
     * @notice Struct for tier price and cap
     */
    struct Tier {
        uint256 price; // Price of the token
        uint256 cap; // Cap for the tier
    }

    struct SaleSchedule {
        uint256 comingSoon; // End timestamp for coming soon phase
        uint256 onlyKyc; // End timestamp of only KYC phase
        uint256 tokenPurchase; // End timestamp of token purchase phase
    }

    struct SaleParameters {
        uint256 minDepositAmount; // Minimum USD amount required per purchase.
        uint256 maxDepositAmount; // Maximum USD amount allowed per wallet.
    }

    // ============== Enums ===============

    enum Stages {
        Completed, // Sale is final
        ComingSoon, // Contract is deployed but not yet started
        OnlyKyc, // Only Merkle root updates and setup functions
        TokenPurchase // Deposit and purchase tokens

    }

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    // ============== Contract Setup ===============

    /**
     * @dev Admin Role: Manages contract parameters setup like sale configuration and recipient of funds
     */
    bytes32 private constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    /**
     * @dev Operator role: updating merkle root
     */
    bytes32 private constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    /**
     * @notice Maximum funds allowed to be collected.
     * @dev 20,000,000 USDC/T (*) times 10^6, 6 is the number of decimals of USDC/USDT.
     */
    uint256 public maxTotalFunds;

    /**
     * @dev Merkle root for whitelist verification.
     */
    bytes32 public merkleRoot;

    /**
     * @dev Recipient of collected funds.
     */
    address private immutable treasury;

    /**
     * @dev Address of USDC token.
     */
    IERC20 private immutable USDC;

    /**
     * @dev Address of USDT token.
     */
    IERC20 private immutable USDT;

    /**
     * @dev Array of Tier structs representing different price tiers in Sale.
     */
    Tier[4] public tiers;

    /**
     * @dev Sale stages timestamps.
     */
    SaleSchedule public saleSchedule;

    /**
     * @dev Sale constraints for each wallet.
     */
    SaleParameters public saleParameters;

    // ============ Tracking the sale =============

    /**
     * @dev Total amount of USD collected so far.
     */
    uint256 public totalFundsCollected;

    /**
     * @dev Price tier tracking.
     */
    uint256 public activeTierIndex;

    /**
     * @dev Mapping to track deposits by each user.
     */
    mapping(address => UserDepositInfo) public userDeposits;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event ExternalContractsSet(address indexed user, address treasury, IERC20 usdc, IERC20 usdt);
    event TiersUpdate(address indexed user, Tier[4] tiers);
    event SaleParametersUpdate(address indexed user, uint256 minDepositAmount, uint256 maxDepositAmount);
    event SaleScheduleUpdate(address indexed user, uint256 comingSoon, uint256 onlyKyc, uint256 tokenPurchase);
    event MerkleRootUpdate(address indexed user, bytes32 newRoot);
    event ActiveTierUpdate(address indexed user, uint256 oldTierIndex, uint256 newTierIndex);
    event TokensPurchase(
        address indexed user, uint256 depositedAmount, uint256 purchasedTokens, uint256 totalFundsCollected
    );
    event SaleCompleted();
    event WithdrawAsset(address asset, address withdrawTo, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Error thrown when a user is not verified.
     * @param _selector The function selector that triggered the error.
     * @param _user The address of the user that is not verified.
     */
    error UserNotVerified(bytes4 _selector, address _user);

    /**
     * @dev Error thrown when the purchase input is invalid.
     * @param _selector The function selector that triggered the error.
     * @param _input The invalid input provided.
     */
    /**
     * @dev Error indicating that the purchase input is invalid.
     * @param _selector The function selector where the error occurred.
     * @param _input The invalid input that was provided.
     * @param _message A message providing additional details about the error.
     * @param _suggestedInput A suggested valid input to correct the error.
     */
    error InvalidPurchaseInput(bytes4 _selector, bytes32 _input, bytes32 _message, uint256 _suggestedInput);

    /**
     * @dev Error thrown when an input is invalid.
     * @param _selector The function selector that triggered the error.
     * @param _input The invalid input provided.
     */
    error InvalidInput(bytes4 _selector, bytes32 _input);

    /**
     * @dev Error thrown when the contract is in the wrong stage.
     * @param _selector The function selector that triggered the error.
     * @param _currentStage The current stage of the contract.
     * @param _requiredStage The required stage for the operation.
     */
    error WrongStage(bytes4 _selector, Stages _currentStage, Stages _requiredStage);

    /*//////////////////////////////////////////////////////////////
                             MODIFIERS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Modifier to check if the sale is in the correct stage
     * @param _requiredStage The minimal required stage for the function to execute
     * @notice Compares stages sequentially: OnlyKyc < TokenPurchase < Completed
     *         If the current stage if before the required stage, the function will revert
     */
    modifier fromStage(Stages _requiredStage) {
        Stages _currentStage = _getCurrentStage();

        // completed = 0, comingSoon = 1, onlyKyc = 2, tokenPurchase = 3
        if (_currentStage < _requiredStage) {
            revert WrongStage(msg.sig, _currentStage, _requiredStage);
        }

        _;
    }

    /**
     * @dev Modifier to ensure that the current stage matches the required stage for the function execution.
     * @param _requiredStage The exact stage required for the function to execute.
     * @notice The function will revert if the current stage is not identical to the required stage.
     */
    modifier atStage(Stages _requiredStage) {
        Stages _currentStage = _getCurrentStage();

        if (_currentStage != _requiredStage) {
            revert WrongStage(msg.sig, _currentStage, _requiredStage);
        }

        _;
    }

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        address _superAdmin,
        address _admin,
        address _operator,
        address _treasury,
        IERC20 _usdc,
        IERC20 _usdt,
        bytes32 _merkleRoot
    ) {
        address ZERO_ADDRESS = address(0);

        require(
            (_superAdmin != ZERO_ADDRESS) && (_admin != ZERO_ADDRESS) && (_operator != ZERO_ADDRESS)
                && (_treasury != ZERO_ADDRESS) && (address(_usdc) != ZERO_ADDRESS) && (address(_usdt) != ZERO_ADDRESS)
                && (_merkleRoot != bytes32(0))
        );

        _pause();

        treasury = _treasury;
        USDC = _usdc;
        USDT = _usdt;
        emit ExternalContractsSet(msg.sender, treasury, USDC, USDT);

        _setMerkleRoot(_merkleRoot);

        // Tier prices are scaled by 10^18 to keep precision during division
        _setTiers(
            [
                Tier(9_090_909_090_909_090, 2_000_000e6), // 0
                Tier(9_523_809_523_809_520, 4_000_000e6), // 1
                Tier(9_708_737_864_077_669, 6_000_000e6), // 2
                Tier(10_263_929_618_768_321, 20_000_000e6) // 3
            ]
        );

        _grantRole(DEFAULT_ADMIN_ROLE, _superAdmin);
        _grantRole(ADMIN_ROLE, _admin);
        _grantRole(OPERATOR_ROLE, _operator);
    }

    /*//////////////////////////////////////////////////////////////
                            CONTRACT SETUP
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Sets the sale parameters including minimum and maximum deposit amounts.
     * @dev This function can only be called by an account with the ADMIN_ROLE and when the contract is paused.
     * @param _minDepositAmount The minimum amount that can be deposited.
     * @param _maxDepositAmount The maximum amount that can be deposited.
     * Emits a {SaleParametersUpdate} event.
     */
    function setSaleParameters(
        uint256 _minDepositAmount,
        uint256 _maxDepositAmount
    )
        external
        whenPaused
        onlyRole(ADMIN_ROLE)
    {
        require(_minDepositAmount < _maxDepositAmount);

        saleParameters = SaleParameters(_minDepositAmount, _maxDepositAmount);
        emit SaleParametersUpdate(msg.sender, _minDepositAmount, _maxDepositAmount);
    }

    /**
     * @notice Sets the sale schedule including KYC and token purchase periods.
     * @dev This function can only be called by an account with the ADMIN_ROLE and when the contract is paused.
     * @param _onlyKyc The timestamp until which users can only KYC.
     * @param _tokenPurchase The timestamp until which token purchases can be made.
     * Emits a {SaleScheduleUpdate} event.
     */
    function setSaleSchedule(
        uint256 _comingSoon,
        uint256 _onlyKyc,
        uint256 _tokenPurchase
    )
        external
        whenPaused
        onlyRole(ADMIN_ROLE)
    {
        require((_comingSoon < _onlyKyc) && (_onlyKyc < _tokenPurchase));

        saleSchedule = SaleSchedule(_comingSoon, _onlyKyc, _tokenPurchase);
        emit SaleScheduleUpdate(msg.sender, _comingSoon, _onlyKyc, _tokenPurchase);
    }

    /**
     * @notice Sets the tiers for the sale.
     * @dev This function can only be called by an account with the ADMIN_ROLE and when the contract is paused.
     * @param _tiers An array of Tier structs representing the different tiers.
     * Emits a {TiersUpdate} event.
     */
    function setTiers(Tier[4] calldata _tiers) public atStage(Stages.OnlyKyc) onlyRole(ADMIN_ROLE) {
        bytes32 tiersHash_ = keccak256(bytes.concat(msg.data[4:]));
        bytes32 zeroBytesHash_ = keccak256(bytes.concat(new bytes(256)));
        require(tiersHash_ != zeroBytesHash_);

        _setTiers(_tiers);
    }

    /*//////////////////////////////////////////////////////////////
                            PUBLIC API
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Deposit using USDC and purchase tokens.
     * @param _amount Amount of USDC to deposit.
     * @param merkleProof Merkle proof for whitelist verification.
     * @dev Emits a Purchase event upon successful purchase.
     */
    function depositUSDC(
        uint256 _amount,
        bytes32[] calldata merkleProof
    )
        external
        whenNotPaused
        fromStage(Stages.TokenPurchase)
    {
        UserDepositInfo storage userDepositInfo = userDeposits[msg.sender];

        _verifyDepositConditions(_amount, userDepositInfo.amountDeposited, merkleProof);
        _purchase(_amount, USDC, userDepositInfo);
    }

    /**
     * @notice Deposit using USDT and purchase tokens.
     * @param _amount Amount of USDT to deposit.
     * @param merkleProof Merkle proof for whitelist verification.
     * @dev Emits a Purchase event upon successful purchase.
     */
    function depositUSDT(
        uint256 _amount,
        bytes32[] calldata merkleProof
    )
        external
        whenNotPaused
        fromStage(Stages.TokenPurchase)
    {
        UserDepositInfo storage userDepositInfo = userDeposits[msg.sender];

        _verifyDepositConditions(_amount, userDepositInfo.amountDeposited, merkleProof);
        _purchase(_amount, USDT, userDepositInfo);
    }

    /**
     * @notice Update the Merkle root for whitelist verification.
     * @param _newRoot The new Merkle root.
     */
    function setMerkleRoot(bytes32 _newRoot) external onlyRole(OPERATOR_ROLE) fromStage(Stages.OnlyKyc) {
        _setMerkleRoot(_newRoot);
    }

    /**
     * @notice Withdraw assets from the contract.
     * @param recipient Address to send the assets to.
     * @param asset Address of the asset to withdraw (e.g., USDC/USDT).
     */
    function withdrawAssets(address recipient, IERC20 asset) external onlyRole(ADMIN_ROLE) {
        uint256 contractBalance = asset.balanceOf(address(this));
        asset.safeTransfer(recipient, contractBalance);
        emit WithdrawAsset(address(asset), recipient, contractBalance);
    }

    /**
     * @notice Pause the contract, preventing deposits.
     */
    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }

    /**
     * @notice Unpause the contract, allowing deposits.
     */
    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }

    /*//////////////////////////////////////////////////////////////
                            PRIVATE API
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Internal function to handle the purchase logic.
     * @param _amountUSD Amount to deposit.
     * @param _asset Asset to deposit (USDC/USDT).
     * @param _userDepositInfo User deposit info.
     * @dev Emits a Purchase event upon successful purchase.
     */
    function _purchase(uint256 _amountUSD, IERC20 _asset, UserDepositInfo storage _userDepositInfo) private {
        (uint256 _resultingTokens, uint256 _remainingAmount, uint256 _resultingTierIndex) =
            _calculateTokensToTransfer(_amountUSD, totalFundsCollected, activeTierIndex, tiers);

        uint256 depositedAmount_ = _amountUSD - _remainingAmount;

        if (_resultingTierIndex > activeTierIndex) {
            emit ActiveTierUpdate(msg.sender, activeTierIndex, _resultingTierIndex);
            activeTierIndex = _resultingTierIndex;
        }

        totalFundsCollected += depositedAmount_;

        _userDepositInfo.amountDeposited += depositedAmount_;
        _userDepositInfo.purchasedTokens += _resultingTokens;

        _asset.safeTransferFrom(msg.sender, treasury, depositedAmount_);

        emit TokensPurchase(msg.sender, depositedAmount_, _resultingTokens, totalFundsCollected);

        if (_getRemainingCap() == 0) {
            _pause();
            emit SaleCompleted();
        }
    }

    /**
     * @notice Internal function to verify deposit conditions like minimum/maximum amount and whitelist.
     * @param _amount Amount to deposit.
     * @param _amountDeposited Amount already deposited by the user.
     * @param merkleProof Merkle proof for whitelist verification.
     * @dev Throws custom errors if any condition fails.
     */
    function _verifyDepositConditions(
        uint256 _amount,
        uint256 _amountDeposited,
        bytes32[] calldata merkleProof
    )
        private
        view
    {
        if (_amount < 10e6) {
            revert InvalidPurchaseInput(msg.sig, bytes32("_amount"), bytes32("at least"), 10e6);
        }

        if (!_verifyUser(msg.sender, merkleProof)) {
            revert UserNotVerified(msg.sig, msg.sender);
        }

        SaleParameters memory _saleParameters = saleParameters;

        if ((_amount + _amountDeposited) < _saleParameters.minDepositAmount) {
            revert InvalidPurchaseInput(
                msg.sig, bytes32("_amount"), bytes32("below minDepositAmount"), _saleParameters.minDepositAmount
            );
        }

        uint256 _remainingAmount = _saleParameters.maxDepositAmount - _amountDeposited;
        if (_amount > _remainingAmount) {
            revert InvalidPurchaseInput(
                msg.sig, bytes32("_amount"), bytes32("exceeds maxDepositAmount"), _remainingAmount
            );
        }
    }

    /**
     * @notice Internal function to set the Merkle root.
     * @param _newRoot The new Merkle root.
     * @dev Emits a {MerkleRootUpdate} event if the new root is set.
     */
    function _setMerkleRoot(bytes32 _newRoot) private {
        if ((_newRoot == bytes32(0)) || (_newRoot == merkleRoot)) revert InvalidInput(msg.sig, bytes32("_newRoot"));

        merkleRoot = _newRoot;
        emit MerkleRootUpdate(msg.sender, _newRoot);
    }

    /**
     * @notice Internal function to set the tiers.
     * @param _tiers An array of Tier structs representing the different tiers.
     * @dev Emits a {TiersUpdate} event if the new tiers are set.
     */
    function _setTiers(Tier[4] memory _tiers) private {
        for (uint256 i = 0; i < 4; i++) {
            tiers[i] = _tiers[i];
        }

        maxTotalFunds = _tiers[3].cap;

        emit TiersUpdate(msg.sender, _tiers);
    }

    /**
     * @notice Internal function to verify if a user is in the whitelist using Merkle proof.
     * @param user Address of the user.
     * @param merkleProof Merkle proof for whitelist verification.
     * @return A boolean indicating whether the user is in the whitelist.
     */
    function _verifyUser(address user, bytes32[] calldata merkleProof) private view returns (bool) {
        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(user))));

        return MerkleProof.verify(merkleProof, merkleRoot, leaf);
    }

    /**
     * @notice Calculates the number of tokens to transfer based on the deposited amount and tiers.
     * @dev This function accounts for multiple tiers and computes tokens across them if necessary.
     * @param _amount The amount deposited by the user.
     * @param _totalFundsCollected The total funds collected so far.
     * @param _activeTierIndex The index of the current active tier.
     * @param _tiers An array containing the details of each tier.
     * @return A tuple containing:
     *         - `resultingTokens_` The total number of tokens to transfer.
     *         - `remainingAmount_` The remaining amount after token computation.
     *         - `resultingTierIndex_` The updated active tier index after processing.
     */
    function _calculateTokensToTransfer(
        uint256 _amount,
        uint256 _totalFundsCollected,
        uint256 _activeTierIndex,
        Tier[4] memory _tiers
    )
        private
        pure
        returns (uint256, uint256, uint256)
    {
        Tier memory _tier = _tiers[_activeTierIndex];
        uint256 _remainingTierCap = _tier.cap - _totalFundsCollected;

        // If amount is within the current tier cap we don't need to split the price into multiple tiers
        if (_amount <= _remainingTierCap) {
            return (_computeTokens(_amount, _tier.price), 0, _activeTierIndex);
        }

        // We're starting to compute the resulting tokens from the current tier
        uint256 remainingAmount_ = _amount;
        uint256 resultingTokens_ = 0;
        uint256 resultingTierIndex_ = _activeTierIndex;

        // By this point we know the amount is larger than the remaining tier cap
        resultingTokens_ += _computeTokens(_remainingTierCap, _tier.price);
        remainingAmount_ -= _remainingTierCap;

        uint256 prevTierCap = _tier.cap;
        uint256 currTierCap = 0;

        // And we continue to compute the resulting tokens based on the next tiers prices
        for (uint256 i = (_activeTierIndex + 1); i < _tiers.length; i++) {
            _tier = _tiers[i];
            resultingTierIndex_ = i;
            currTierCap = _tier.cap - prevTierCap;

            if (remainingAmount_ <= currTierCap) {
                resultingTokens_ += _computeTokens(remainingAmount_, _tier.price);
                remainingAmount_ = 0;
                break;
            }

            resultingTokens_ += _computeTokens(currTierCap, _tier.price);
            remainingAmount_ -= currTierCap;
            prevTierCap = _tier.cap;
        }

        return (resultingTokens_, remainingAmount_, resultingTierIndex_);
    }

    /**
     * @param _amount The amount in USD
     * @param _price The price of the token in USD
     */
    function _computeTokens(uint256 _amount, uint256 _price) private pure returns (uint256) {
        // _price = price * 10^18 --> precision scaling
        // _amount = (input_amount * 10^6 (USDC/T)) * 10^18 (_price)
        // (_amount * 1e18) / _price = (10^6 * 10^18) / 10^18 = 10^6 precision
        // 10^6 * 10^12 = 10^18 --> scale for future token's decimals
        return ((_amount * 1e18) / _price) * 1e12;
    }

    /**
     * @notice Retrieve the current stage of the sale.
     * @dev Evaluates the current timestamp against the predefined sale schedule stages.
     * @return The current stage which can be one of the stages:
     *         - `Stages.ComingSoon`: Sale has not started yet.
     *         - `Stages.OnlyKyc`: Only KYC available, purchase not yet allowed.
     *         - `Stages.TokenPurchase`: Sale is active, allowing token purchases.
     *         - `Stages.Completed`: Sale has ended.
     */
    function _getCurrentStage() private view returns (Stages) {
        if (block.timestamp < saleSchedule.comingSoon) return Stages.ComingSoon;
        if (block.timestamp < saleSchedule.onlyKyc) return Stages.OnlyKyc;
        if (block.timestamp < saleSchedule.tokenPurchase) return Stages.TokenPurchase;

        return Stages.Completed;
    }

    /**
     * @notice Get the remaining cap for the total funds that can be collected.
     * @dev This function computes the remaining amount of funds that can be collected
     *      by subtracting the total funds already collected from the maximum allowed funds.
     * @return The remaining cap amount.
     */
    function _getRemainingCap() private view returns (uint256) {
        return maxTotalFunds - totalFundsCollected;
    }

    /*//////////////////////////////////////////////////////////////
                                 VIEWS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Retrieve the current stage of the sale.
     * @dev Evaluates the current timestamp against the predefined sale schedule stages.
     * @return The current stage which can be one of the stages:
     *         - `Stages.ComingSoon`: Sale has not started yet.
     *         - `Stages.OnlyKyc`: Only KYC available, purchase not yet allowed.
     *         - `Stages.TokenPurchase`: Sale is active, allowing token purchases.
     *         - `Stages.Completed`: Sale has ended.
     */
    function getCurrentStage() external view returns (Stages) {
        return _getCurrentStage();
    }

    /**
     * @notice Check if user able to deposit
     * @param user Address of user
     * @param merkleProof Proof for user
     */
    function verifyUser(address user, bytes32[] calldata merkleProof) external view returns (bool) {
        return _verifyUser(user, merkleProof);
    }

    /**
     * @notice Get the remaining deposit amount for a given user.
     * @param _user Address of the user.
     * @return The remaining deposit amount that the user can still deposit.
     */
    function getRemainingDepositAmount(address _user) external view returns (uint256) {
        return saleParameters.maxDepositAmount - userDeposits[_user].amountDeposited;
    }

    /**
     * @notice Get the remaining cap for the sale.
     * @return The remaining cap amount for the total funds collected in the sale.
     */
    function getRemainingCap() external view returns (uint256) {
        return _getRemainingCap();
    }
}
