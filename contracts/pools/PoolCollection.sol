// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.13;

import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";

import { Token } from "../token/Token.sol";
import { TokenLibrary } from "../token/TokenLibrary.sol";

import { IMasterVault } from "../vaults/interfaces/IMasterVault.sol";
import { IExternalProtectionVault } from "../vaults/interfaces/IExternalProtectionVault.sol";

import { IVersioned } from "../utility/interfaces/IVersioned.sol";

import { PPM_RESOLUTION } from "../utility/Constants.sol";
import { Owned } from "../utility/Owned.sol";
import { BlockNumber } from "../utility/BlockNumber.sol";
import { Fraction, Fraction112, FractionLibrary, zeroFraction, zeroFraction112 } from "../utility/FractionLibrary.sol";
import { Sint256, MathEx } from "../utility/MathEx.sol";

// prettier-ignore
import {
    Utils,
    AlreadyExists,
    DoesNotExist,
    InvalidParam,
    InvalidPoolCollection,
    InvalidStakedBalance
} from "../utility/Utils.sol";

import { INetworkSettings, NotWhitelisted } from "../network/interfaces/INetworkSettings.sol";
import { IBancorNetwork } from "../network/interfaces/IBancorNetwork.sol";

import { IPoolToken } from "./interfaces/IPoolToken.sol";
import { IPoolTokenFactory } from "./interfaces/IPoolTokenFactory.sol";
import { IPoolMigrator } from "./interfaces/IPoolMigrator.sol";

// prettier-ignore
import {
    AverageRates,
    IPoolCollection,
    PoolLiquidity,
    Pool,
    TRADING_STATUS_UPDATE_DEFAULT,
    TRADING_STATUS_UPDATE_ADMIN,
    TRADING_STATUS_UPDATE_MIN_LIQUIDITY,
    TradeAmountAndFee,
    WithdrawalAmounts
} from "./interfaces/IPoolCollection.sol";

import { IBNTPool } from "./interfaces/IBNTPool.sol";

import { PoolCollectionWithdrawal } from "./PoolCollectionWithdrawal.sol";

// base token withdrawal output amounts
struct InternalWithdrawalAmounts {
    uint256 baseTokensToTransferFromMasterVault; // base token amount to transfer from the master vault to the provider
    uint256 bntToMintForProvider; // BNT amount to mint directly for the provider
    uint256 baseTokensToTransferFromEPV; // base token amount to transfer from the external protection vault to the provider
    Sint256 baseTokensTradingLiquidityDelta; // base token amount to add to the trading liquidity
    Sint256 bntTradingLiquidityDelta; // BNT amount to add to the trading liquidity and to the master vault
    Sint256 bntProtocolHoldingsDelta; // BNT amount add to the protocol equity
    uint256 baseTokensWithdrawalFee; // base token amount to keep in the pool as a withdrawal fee
    uint256 baseTokensWithdrawalAmount; // base token amount equivalent to the base pool token's withdrawal amount
    uint256 poolTokenAmount; // base pool token
    uint256 poolTokenTotalSupply; // base pool token's total supply
    uint256 newBaseTokenTradingLiquidity; // new base token trading liquidity
    uint256 newBNTTradingLiquidity; // new BNT trading liquidity
}

struct TradingLiquidityAction {
    bool update;
    uint256 newAmount;
}

enum PoolRateState {
    Uninitialized,
    Unstable,
    Stable
}

/**
 * @dev Pool Collection contract
 *
 * notes:
 *
 * - the address of reserve token serves as the pool unique ID in both contract functions and events
 */
contract PoolCollection is IPoolCollection, Owned, BlockNumber, Utils {
    using TokenLibrary for Token;
    using FractionLibrary for Fraction;
    using FractionLibrary for Fraction112;
    using EnumerableSet for EnumerableSet.AddressSet;

    error AlreadyEnabled();
    error DepositingDisabled();
    error InsufficientLiquidity();
    error InsufficientSourceAmount();
    error InsufficientTargetAmount();
    error InvalidRate();
    error RateUnstable();
    error TradingDisabled();
    error FundingLimitTooHigh();

    uint16 private constant POOL_TYPE = 1;
    uint256 private constant LIQUIDITY_GROWTH_FACTOR = 2;
    uint256 private constant BOOTSTRAPPING_LIQUIDITY_BUFFER_FACTOR = 2;
    uint32 private constant DEFAULT_TRADING_FEE_PPM = 2_000; // 0.2%
    uint32 private constant RATE_MAX_DEVIATION_PPM = 10_000; // %1

    // the average rate is recalculated based on the ratio between the weights of the rates the smaller the weights are,
    // the larger the supported range of each one of the rates is
    uint256 private constant EMA_AVERAGE_RATE_WEIGHT = 4;
    uint256 private constant EMA_SPOT_RATE_WEIGHT = 1;

    struct TradeIntermediateResult {
        uint256 sourceAmount;
        uint256 targetAmount;
        uint256 limit;
        uint256 tradingFeeAmount;
        uint256 networkFeeAmount;
        uint256 sourceBalance;
        uint256 targetBalance;
        uint256 stakedBalance;
        Token pool;
        bool isSourceBNT;
        bool bySourceAmount;
        uint32 tradingFeePPM;
        bytes32 contextId;
    }

    struct TradeAmountAndTradingFee {
        uint256 amount;
        uint256 tradingFeeAmount;
    }

    // the network contract
    IBancorNetwork private immutable _network;

    // the address of the BNT token
    IERC20 private immutable _bnt;

    // the network settings contract
    INetworkSettings private immutable _networkSettings;

    // the master vault contract
    IMasterVault private immutable _masterVault;

    // the BNT pool contract
    IBNTPool internal immutable _bntPool;

    // the address of the external protection vault
    IExternalProtectionVault private immutable _externalProtectionVault;

    // the pool token factory contract
    IPoolTokenFactory private immutable _poolTokenFactory;

    // the pool migrator contract
    IPoolMigrator private immutable _poolMigrator;

    // a mapping between tokens and their pools
    mapping(Token => Pool) internal _poolData;

    // the set of all pools which are managed by this pool collection
    EnumerableSet.AddressSet private _pools;

    // the default trading fee (in units of PPM)
    uint32 private _defaultTradingFeePPM;

    /**
     * @dev triggered when the default trading fee is updated
     */
    event DefaultTradingFeePPMUpdated(uint32 prevFeePPM, uint32 newFeePPM);

    /**
     * @dev triggered when a specific pool's trading fee is updated
     */
    event TradingFeePPMUpdated(Token indexed pool, uint32 prevFeePPM, uint32 newFeePPM);

    /**
     * @dev triggered when trading in a specific pool is enabled/disabled
     */
    event TradingEnabled(Token indexed pool, bool indexed newStatus, uint8 indexed reason);

    /**
     * @dev triggered when depositing into a specific pool is enabled/disabled
     */
    event DepositingEnabled(Token indexed pool, bool indexed newStatus);

    /**
     * @dev triggered when new liquidity is deposited into a pool
     */
    event TokensDeposited(
        bytes32 indexed contextId,
        address indexed provider,
        Token indexed token,
        uint256 tokenAmount,
        uint256 poolTokenAmount
    );

    /**
     * @dev triggered when existing liquidity is withdrawn from a pool
     */
    event TokensWithdrawn(
        bytes32 indexed contextId,
        address indexed provider,
        Token indexed token,
        uint256 tokenAmount,
        uint256 poolTokenAmount,
        uint256 externalProtectionBaseTokenAmount,
        uint256 bntAmount,
        uint256 withdrawalFeeAmount
    );

    /**
     * @dev triggered when the trading liquidity in a pool is updated
     */
    event TradingLiquidityUpdated(
        bytes32 indexed contextId,
        Token indexed pool,
        Token indexed token,
        uint256 prevLiquidity,
        uint256 newLiquidity
    );

    /**
     * @dev triggered when the total liquidity in a pool is updated
     */
    event TotalLiquidityUpdated(
        bytes32 indexed contextId,
        Token indexed pool,
        uint256 liquidity,
        uint256 stakedBalance,
        uint256 poolTokenSupply
    );

    /**
     * @dev initializes a new PoolCollection contract
     */
    constructor(
        IBancorNetwork initNetwork,
        IERC20 initBNT,
        INetworkSettings initNetworkSettings,
        IMasterVault initMasterVault,
        IBNTPool initBNTPool,
        IExternalProtectionVault initExternalProtectionVault,
        IPoolTokenFactory initPoolTokenFactory,
        IPoolMigrator initPoolMigrator
    )
        validAddress(address(initNetwork))
        validAddress(address(initBNT))
        validAddress(address(initNetworkSettings))
        validAddress(address(initMasterVault))
        validAddress(address(initBNTPool))
        validAddress(address(initExternalProtectionVault))
        validAddress(address(initPoolTokenFactory))
        validAddress(address(initPoolMigrator))
    {
        _network = initNetwork;
        _bnt = initBNT;
        _networkSettings = initNetworkSettings;
        _masterVault = initMasterVault;
        _bntPool = initBNTPool;
        _externalProtectionVault = initExternalProtectionVault;
        _poolTokenFactory = initPoolTokenFactory;
        _poolMigrator = initPoolMigrator;

        _setDefaultTradingFeePPM(DEFAULT_TRADING_FEE_PPM);
    }

    /**
     * @inheritdoc IVersioned
     */
    function version() external view virtual returns (uint16) {
        return 5;
    }

    /**
     * @inheritdoc IPoolCollection
     */
    function poolType() external view virtual returns (uint16) {
        return POOL_TYPE;
    }

    /**
     * @inheritdoc IPoolCollection
     */
    function defaultTradingFeePPM() external view returns (uint32) {
        return _defaultTradingFeePPM;
    }

    /**
     * @inheritdoc IPoolCollection
     */
    function pools() external view returns (Token[] memory) {
        uint256 length = _pools.length();
        Token[] memory list = new Token[](length);
        for (uint256 i = 0; i < length; i++) {
            list[i] = Token(_pools.at(i));
        }
        return list;
    }

    /**
     * @inheritdoc IPoolCollection
     */
    function poolCount() external view returns (uint256) {
        return _pools.length();
    }

    /**
     * @dev sets the default trading fee (in units of PPM)
     *
     * requirements:
     *
     * - the caller must be the owner of the contract
     */
    function setDefaultTradingFeePPM(uint32 newDefaultTradingFeePPM)
        external
        onlyOwner
        validFee(newDefaultTradingFeePPM)
    {
        _setDefaultTradingFeePPM(newDefaultTradingFeePPM);
    }

    /**
     * @inheritdoc IPoolCollection
     */
    function createPool(Token token) external only(address(_network)) {
        if (!_networkSettings.isTokenWhitelisted(token)) {
            revert NotWhitelisted();
        }

        IPoolToken newPoolToken = IPoolToken(_poolTokenFactory.createPoolToken(token));

        newPoolToken.acceptOwnership();

        Pool memory newPool = Pool({
            poolToken: newPoolToken,
            tradingFeePPM: _defaultTradingFeePPM,
            tradingEnabled: false,
            depositingEnabled: true,
            averageRates: AverageRates({ blockNumber: 0, rate: zeroFraction112(), invRate: zeroFraction112() }),
            liquidity: PoolLiquidity({ bntTradingLiquidity: 0, baseTokenTradingLiquidity: 0, stakedBalance: 0 })
        });

        _addPool(token, newPool);

        emit TradingEnabled({ pool: token, newStatus: newPool.tradingEnabled, reason: TRADING_STATUS_UPDATE_DEFAULT });
        emit TradingFeePPMUpdated({ pool: token, prevFeePPM: 0, newFeePPM: newPool.tradingFeePPM });
        emit DepositingEnabled({ pool: token, newStatus: newPool.depositingEnabled });
    }

    /**
     * @inheritdoc IPoolCollection
     */
    function isPoolValid(Token pool) external view returns (bool) {
        return address(_poolData[pool].poolToken) != address(0);
    }

    /**
     * @dev returns specific pool's data
     *
     * notes:
     *
     * - there is no guarantee that this function will remains forward compatible, so please avoid relying on it and
     *   rely on specific getters from the IPoolCollection interface instead
     */
    function poolData(Token pool) external view returns (Pool memory) {
        return _poolData[pool];
    }

    /**
     * @inheritdoc IPoolCollection
     */
    function poolLiquidity(Token pool) external view returns (PoolLiquidity memory) {
        return _poolData[pool].liquidity;
    }

    /**
     * @inheritdoc IPoolCollection
     */
    function poolToken(Token pool) external view returns (IPoolToken) {
        return _poolData[pool].poolToken;
    }

    /**
     * @inheritdoc IPoolCollection
     */
    function tradingFeePPM(Token pool) external view returns (uint32) {
        return _poolData[pool].tradingFeePPM;
    }

    /**
     * @inheritdoc IPoolCollection
     */
    function tradingEnabled(Token pool) external view returns (bool) {
        return _poolData[pool].tradingEnabled;
    }

    /**
     * @inheritdoc IPoolCollection
     */
    function depositingEnabled(Token pool) external view returns (bool) {
        return _poolData[pool].depositingEnabled;
    }

    /**
     * @inheritdoc IPoolCollection
     */
    function poolTokenToUnderlying(Token pool, uint256 poolTokenAmount) external view returns (uint256) {
        Pool storage data = _poolData[pool];

        return _poolTokenToUnderlying(poolTokenAmount, data.poolToken.totalSupply(), data.liquidity.stakedBalance);
    }

    /**
     * @inheritdoc IPoolCollection
     */
    function underlyingToPoolToken(Token pool, uint256 tokenAmount) external view returns (uint256) {
        Pool storage data = _poolData[pool];

        return _underlyingToPoolToken(tokenAmount, data.poolToken.totalSupply(), data.liquidity.stakedBalance);
    }

    /**
     * @inheritdoc IPoolCollection
     */
    function poolTokenAmountToBurn(
        Token pool,
        uint256 tokenAmountToDistribute,
        uint256 protocolPoolTokenAmount
    ) external view returns (uint256) {
        if (tokenAmountToDistribute == 0) {
            return 0;
        }

        Pool storage data = _poolData[pool];

        uint256 poolTokenSupply = data.poolToken.totalSupply();
        uint256 val = tokenAmountToDistribute * poolTokenSupply;

        return
            MathEx.mulDivF(
                val,
                poolTokenSupply,
                val + data.liquidity.stakedBalance * (poolTokenSupply - protocolPoolTokenAmount)
            );
    }

    /**
     * @inheritdoc IPoolCollection
     */
    function isPoolStable(Token pool) external view returns (bool) {
        Pool storage data = _poolData[pool];

        return _poolRateState(data.liquidity, data.averageRates) == PoolRateState.Stable;
    }

    /**
     * @dev sets the trading fee of a given pool
     *
     * requirements:
     *
     * - the caller must be the owner of the contract
     */
    function setTradingFeePPM(Token pool, uint32 newTradingFeePPM) external onlyOwner validFee(newTradingFeePPM) {
        Pool storage data = _poolStorage(pool);

        uint32 prevTradingFeePPM = data.tradingFeePPM;
        if (prevTradingFeePPM == newTradingFeePPM) {
            return;
        }

        data.tradingFeePPM = newTradingFeePPM;

        emit TradingFeePPMUpdated({ pool: pool, prevFeePPM: prevTradingFeePPM, newFeePPM: newTradingFeePPM });
    }

    /**
     * @dev enables trading in a given pool, by providing the funding rate as two virtual balances, and updates its
     * trading liquidity
     *
     * please note that the virtual balances should be derived from token prices, normalized to the smallest unit of
     * tokens. For example:
     *
     * - if the price of one (10**18 wei) BNT is $X and the price of one (10**18 wei) TKN is $Y, then the virtual balances
     *   should represent a ratio of X to Y
     * - if the price of one (10**18 wei) BNT is $X and the price of one (10**6 wei) USDC is $Y, then the virtual balances
     *   should represent a ratio of X to Y*10**12
     *
     * requirements:
     *
     * - the caller must be the owner of the contract
     */
    function enableTrading(
        Token pool,
        uint256 bntVirtualBalance,
        uint256 baseTokenVirtualBalance
    ) external onlyOwner {
        Fraction memory fundingRate = Fraction({ n: bntVirtualBalance, d: baseTokenVirtualBalance });
        _validRate(fundingRate);

        Pool storage data = _poolStorage(pool);

        if (data.tradingEnabled) {
            revert AlreadyEnabled();
        }

        // adjust the trading liquidity based on the base token vault balance and funding limits
        uint256 minLiquidityForTrading = _networkSettings.minLiquidityForTrading();
        _updateTradingLiquidity(bytes32(0), pool, data, data.liquidity, fundingRate, minLiquidityForTrading);

        // verify that the BNT trading liquidity is equal or greater than the minimum liquidity for trading
        if (data.liquidity.bntTradingLiquidity < minLiquidityForTrading) {
            revert InsufficientLiquidity();
        }

        Fraction112 memory fundingRate112 = fundingRate.toFraction112();
        data.averageRates = AverageRates({
            blockNumber: _blockNumber(),
            rate: fundingRate112,
            invRate: fundingRate112.inverse()
        });

        data.tradingEnabled = true;

        emit TradingEnabled({ pool: pool, newStatus: true, reason: TRADING_STATUS_UPDATE_ADMIN });
    }

    /**
     * @dev disables trading in a given pool
     *
     * requirements:
     *
     * - the caller must be the owner of the contract
     */
    function disableTrading(Token pool) external onlyOwner {
        Pool storage data = _poolStorage(pool);

        _resetTradingLiquidity(bytes32(0), pool, data, TRADING_STATUS_UPDATE_ADMIN);
    }

    /**
     * @dev enables/disables depositing into a given pool
     *
     * requirements:
     *
     * - the caller must be the owner of the contract
     */
    function enableDepositing(Token pool, bool status) external onlyOwner {
        Pool storage data = _poolStorage(pool);

        if (data.depositingEnabled == status) {
            return;
        }

        data.depositingEnabled = status;

        emit DepositingEnabled({ pool: pool, newStatus: status });
    }

    /**
     * @inheritdoc IPoolCollection
     */
    function depositFor(
        bytes32 contextId,
        address provider,
        Token pool,
        uint256 tokenAmount
    ) external only(address(_network)) validAddress(provider) greaterThanZero(tokenAmount) returns (uint256) {
        Pool storage data = _poolStorage(pool);

        if (!data.depositingEnabled) {
            revert DepositingDisabled();
        }

        // calculate the pool token amount to mint
        uint256 currentStakedBalance = data.liquidity.stakedBalance;
        uint256 prevPoolTokenTotalSupply = data.poolToken.totalSupply();
        uint256 poolTokenAmount = _underlyingToPoolToken(tokenAmount, prevPoolTokenTotalSupply, currentStakedBalance);

        PoolLiquidity memory prevLiquidity = data.liquidity;

        // update the staked balance with the full base token amount
        data.liquidity.stakedBalance = currentStakedBalance + tokenAmount;

        // mint pool tokens to the provider
        data.poolToken.mint(provider, poolTokenAmount);

        // adjust the trading liquidity based on the base token vault balance and funding limits
        _updateTradingLiquidity(
            contextId,
            pool,
            data,
            data.liquidity,
            data.averageRates.rate.fromFraction112(),
            _networkSettings.minLiquidityForTrading()
        );

        // if trading is enabled, then update the recent average rates
        if (data.tradingEnabled) {
            _updateAverageRates(
                data,
                Fraction({ n: data.liquidity.bntTradingLiquidity, d: data.liquidity.baseTokenTradingLiquidity })
            );
        }

        emit TokensDeposited({
            contextId: contextId,
            provider: provider,
            token: pool,
            tokenAmount: tokenAmount,
            poolTokenAmount: poolTokenAmount
        });

        _dispatchTradingLiquidityEvents(
            contextId,
            pool,
            prevPoolTokenTotalSupply + poolTokenAmount,
            prevLiquidity,
            data.liquidity
        );

        return poolTokenAmount;
    }

    /**
     * @inheritdoc IPoolCollection
     */
    function withdraw(
        bytes32 contextId,
        address provider,
        Token pool,
        uint256 poolTokenAmount,
        uint256 baseTokenAmount
    )
        external
        only(address(_network))
        validAddress(provider)
        greaterThanZero(poolTokenAmount)
        greaterThanZero(baseTokenAmount)
        returns (uint256)
    {
        Pool storage data = _poolStorage(pool);
        PoolLiquidity memory liquidity = data.liquidity;

        uint256 poolTokenTotalSupply = data.poolToken.totalSupply();
        uint256 underlyingAmount = _poolTokenToUnderlying(
            poolTokenAmount,
            poolTokenTotalSupply,
            liquidity.stakedBalance
        );

        if (baseTokenAmount > underlyingAmount) {
            revert InvalidParam();
        }

        // obtain the withdrawal amounts
        InternalWithdrawalAmounts memory amounts = _poolWithdrawalAmounts(
            pool,
            poolTokenAmount,
            baseTokenAmount,
            liquidity,
            data.tradingFeePPM,
            poolTokenTotalSupply
        );

        // execute the actual withdrawal
        _executeWithdrawal(contextId, provider, pool, data, amounts);

        // if trading is enabled, then update the recent average rates
        if (data.tradingEnabled) {
            _updateAverageRates(
                data,
                Fraction({ n: data.liquidity.bntTradingLiquidity, d: data.liquidity.baseTokenTradingLiquidity })
            );
        }

        return amounts.baseTokensToTransferFromMasterVault;
    }

    /**
     * @inheritdoc IPoolCollection
     */
    function withdrawalAmounts(Token pool, uint256 poolTokenAmount)
        external
        view
        validAddress(address(pool))
        greaterThanZero(poolTokenAmount)
        returns (WithdrawalAmounts memory)
    {
        Pool storage data = _poolData[pool];
        PoolLiquidity memory liquidity = data.liquidity;

        uint256 poolTokenTotalSupply = data.poolToken.totalSupply();
        uint256 underlyingAmount = _poolTokenToUnderlying(
            poolTokenAmount,
            poolTokenTotalSupply,
            liquidity.stakedBalance
        );

        InternalWithdrawalAmounts memory amounts = _poolWithdrawalAmounts(
            pool,
            poolTokenAmount,
            underlyingAmount,
            liquidity,
            data.tradingFeePPM,
            poolTokenTotalSupply
        );

        return
            WithdrawalAmounts({
                totalAmount: amounts.baseTokensWithdrawalAmount - amounts.baseTokensWithdrawalFee,
                baseTokenAmount: amounts.baseTokensToTransferFromMasterVault + amounts.baseTokensToTransferFromEPV,
                bntAmount: amounts.bntToMintForProvider
            });
    }

    /**
     * @inheritdoc IPoolCollection
     */
    function tradeBySourceAmount(
        bytes32 contextId,
        Token sourceToken,
        Token targetToken,
        uint256 sourceAmount,
        uint256 minReturnAmount
    )
        external
        only(address(_network))
        greaterThanZero(sourceAmount)
        greaterThanZero(minReturnAmount)
        returns (TradeAmountAndFee memory)
    {
        TradeIntermediateResult memory result = _initTrade(
            contextId,
            sourceToken,
            targetToken,
            sourceAmount,
            minReturnAmount,
            true
        );

        _performTrade(result);

        return
            TradeAmountAndFee({
                amount: result.targetAmount,
                tradingFeeAmount: result.tradingFeeAmount,
                networkFeeAmount: result.networkFeeAmount
            });
    }

    /**
     * @inheritdoc IPoolCollection
     */
    function tradeByTargetAmount(
        bytes32 contextId,
        Token sourceToken,
        Token targetToken,
        uint256 targetAmount,
        uint256 maxSourceAmount
    )
        external
        only(address(_network))
        greaterThanZero(targetAmount)
        greaterThanZero(maxSourceAmount)
        returns (TradeAmountAndFee memory)
    {
        TradeIntermediateResult memory result = _initTrade(
            contextId,
            sourceToken,
            targetToken,
            targetAmount,
            maxSourceAmount,
            false
        );

        _performTrade(result);

        return
            TradeAmountAndFee({
                amount: result.sourceAmount,
                tradingFeeAmount: result.tradingFeeAmount,
                networkFeeAmount: result.networkFeeAmount
            });
    }

    /**
     * @inheritdoc IPoolCollection
     */
    function tradeOutputAndFeeBySourceAmount(
        Token sourceToken,
        Token targetToken,
        uint256 sourceAmount
    ) external view greaterThanZero(sourceAmount) returns (TradeAmountAndFee memory) {
        TradeIntermediateResult memory result = _initTrade(bytes32(0), sourceToken, targetToken, sourceAmount, 1, true);

        _processTrade(result);

        return
            TradeAmountAndFee({
                amount: result.targetAmount,
                tradingFeeAmount: result.tradingFeeAmount,
                networkFeeAmount: result.networkFeeAmount
            });
    }

    /**
     * @inheritdoc IPoolCollection
     */
    function tradeInputAndFeeByTargetAmount(
        Token sourceToken,
        Token targetToken,
        uint256 targetAmount
    ) external view greaterThanZero(targetAmount) returns (TradeAmountAndFee memory) {
        TradeIntermediateResult memory result = _initTrade(
            bytes32(0),
            sourceToken,
            targetToken,
            targetAmount,
            type(uint256).max,
            false
        );

        _processTrade(result);

        return
            TradeAmountAndFee({
                amount: result.sourceAmount,
                tradingFeeAmount: result.tradingFeeAmount,
                networkFeeAmount: result.networkFeeAmount
            });
    }

    /**
     * @inheritdoc IPoolCollection
     */
    function onFeesCollected(Token pool, uint256 feeAmount) external only(address(_network)) {
        if (feeAmount == 0) {
            return;
        }

        Pool storage data = _poolStorage(pool);

        // increase the staked balance by the given amount
        data.liquidity.stakedBalance += feeAmount;
    }

    /**
     * @inheritdoc IPoolCollection
     */
    function migratePoolIn(Token pool, Pool calldata data)
        external
        validAddress(address(pool))
        only(address(_poolMigrator))
    {
        _addPool(pool, data);

        data.poolToken.acceptOwnership();
    }

    /**
     * @inheritdoc IPoolCollection
     */
    function migratePoolOut(Token pool, IPoolCollection targetPoolCollection)
        external
        validAddress(address(targetPoolCollection))
        only(address(_poolMigrator))
    {
        IPoolToken cachedPoolToken = _poolData[pool].poolToken;

        _removePool(pool);

        cachedPoolToken.transferOwnership(address(targetPoolCollection));
    }

    /**
     * @dev adds a pool
     */
    function _addPool(Token pool, Pool memory data) private {
        if (!_pools.add(address(pool))) {
            revert AlreadyExists();
        }

        _poolData[pool] = data;
    }

    /**
     * @dev removes a pool
     */
    function _removePool(Token pool) private {
        if (!_pools.remove(address(pool))) {
            revert DoesNotExist();
        }

        delete _poolData[pool];
    }

    /**
     * @dev returns withdrawal amounts
     */
    function _poolWithdrawalAmounts(
        Token pool,
        uint256 poolTokenAmount,
        uint256 baseTokensWithdrawalAmount,
        PoolLiquidity memory liquidity,
        uint32 poolTradingFeePPM,
        uint256 poolTokenTotalSupply
    ) internal view returns (InternalWithdrawalAmounts memory) {
        // the base token trading liquidity of a given pool can never be higher than the base token balance of the vault
        // whenever the base token trading liquidity is updated, it is set to at most the base token balance of the vault
        uint256 baseTokenExcessAmount = pool.balanceOf(address(_masterVault)) - liquidity.baseTokenTradingLiquidity;

        PoolCollectionWithdrawal.Output memory output = PoolCollectionWithdrawal.calculateWithdrawalAmounts(
            liquidity.bntTradingLiquidity,
            liquidity.baseTokenTradingLiquidity,
            baseTokenExcessAmount,
            liquidity.stakedBalance,
            pool.balanceOf(address(_externalProtectionVault)),
            poolTradingFeePPM,
            _networkSettings.withdrawalFeePPM(),
            baseTokensWithdrawalAmount
        );

        return
            InternalWithdrawalAmounts({
                baseTokensToTransferFromMasterVault: output.s,
                bntToMintForProvider: output.t,
                baseTokensToTransferFromEPV: output.u,
                baseTokensTradingLiquidityDelta: output.r,
                bntTradingLiquidityDelta: output.p,
                bntProtocolHoldingsDelta: output.q,
                baseTokensWithdrawalFee: output.v,
                baseTokensWithdrawalAmount: baseTokensWithdrawalAmount,
                poolTokenAmount: poolTokenAmount,
                poolTokenTotalSupply: poolTokenTotalSupply,
                newBaseTokenTradingLiquidity: output.r.isNeg
                    ? liquidity.baseTokenTradingLiquidity - output.r.value
                    : liquidity.baseTokenTradingLiquidity + output.r.value,
                newBNTTradingLiquidity: output.p.isNeg
                    ? liquidity.bntTradingLiquidity - output.p.value
                    : liquidity.bntTradingLiquidity + output.p.value
            });
    }

    /**
     * @dev executes the following actions:
     *
     * - burn the network's base pool tokens
     * - update the pool's base token staked balance
     * - update the pool's base token trading liquidity
     * - update the pool's BNT trading liquidity
     * - update the pool's trading liquidity product
     * - emit an event if the pool's BNT trading liquidity has crossed the minimum threshold
     *   (either above the threshold or below the threshold)
     */
    function _executeWithdrawal(
        bytes32 contextId,
        address provider,
        Token pool,
        Pool storage data,
        InternalWithdrawalAmounts memory amounts
    ) private {
        PoolLiquidity storage liquidity = data.liquidity;
        PoolLiquidity memory prevLiquidity = liquidity;
        AverageRates memory averageRates = data.averageRates;

        if (_poolRateState(prevLiquidity, averageRates) == PoolRateState.Unstable) {
            revert RateUnstable();
        }

        data.poolToken.burn(amounts.poolTokenAmount);

        uint256 newPoolTokenTotalSupply = amounts.poolTokenTotalSupply - amounts.poolTokenAmount;

        liquidity.stakedBalance = MathEx.mulDivF(
            liquidity.stakedBalance,
            newPoolTokenTotalSupply,
            amounts.poolTokenTotalSupply
        );

        // trading liquidity is assumed to never exceed 128 bits (the cast below will revert otherwise)
        liquidity.baseTokenTradingLiquidity = SafeCast.toUint128(amounts.newBaseTokenTradingLiquidity);
        liquidity.bntTradingLiquidity = SafeCast.toUint128(amounts.newBNTTradingLiquidity);

        if (amounts.bntProtocolHoldingsDelta.value > 0) {
            assert(amounts.bntProtocolHoldingsDelta.isNeg); // currently no support for requesting funding here

            _bntPool.renounceFunding(contextId, pool, amounts.bntProtocolHoldingsDelta.value);
        } else if (amounts.bntTradingLiquidityDelta.value > 0) {
            if (amounts.bntTradingLiquidityDelta.isNeg) {
                _bntPool.burnFromVault(amounts.bntTradingLiquidityDelta.value);
            } else {
                _bntPool.mint(address(_masterVault), amounts.bntTradingLiquidityDelta.value);
            }
        }

        // if the provider should receive some BNT - ask the BNT pool to mint BNT to the provider
        if (amounts.bntToMintForProvider > 0) {
            _bntPool.mint(address(provider), amounts.bntToMintForProvider);
        }

        // if the provider should receive some base tokens from the external protection vault - remove the tokens from
        // the external protection vault and send them to the master vault
        if (amounts.baseTokensToTransferFromEPV > 0) {
            _externalProtectionVault.withdrawFunds(
                pool,
                payable(address(_masterVault)),
                amounts.baseTokensToTransferFromEPV
            );
            amounts.baseTokensToTransferFromMasterVault += amounts.baseTokensToTransferFromEPV;
        }

        // if the provider should receive some base tokens from the master vault - remove the tokens from the master
        // vault and send them to the provider
        if (amounts.baseTokensToTransferFromMasterVault > 0) {
            _masterVault.withdrawFunds(pool, payable(provider), amounts.baseTokensToTransferFromMasterVault);
        }

        // ensure that the average rate is reset when the pool is being emptied
        if (amounts.newBaseTokenTradingLiquidity == 0) {
            data.averageRates.rate = zeroFraction112();
            data.averageRates.invRate = zeroFraction112();
        }

        // if the new BNT trading liquidity is below the minimum liquidity for trading - reset the liquidity
        if (amounts.newBNTTradingLiquidity < _networkSettings.minLiquidityForTrading()) {
            _resetTradingLiquidity(
                contextId,
                pool,
                data,
                amounts.newBNTTradingLiquidity,
                TRADING_STATUS_UPDATE_MIN_LIQUIDITY
            );
        }

        emit TokensWithdrawn({
            contextId: contextId,
            provider: provider,
            token: pool,
            tokenAmount: amounts.baseTokensToTransferFromMasterVault,
            poolTokenAmount: amounts.poolTokenAmount,
            externalProtectionBaseTokenAmount: amounts.baseTokensToTransferFromEPV,
            bntAmount: amounts.bntToMintForProvider,
            withdrawalFeeAmount: amounts.baseTokensWithdrawalFee
        });

        _dispatchTradingLiquidityEvents(contextId, pool, newPoolTokenTotalSupply, prevLiquidity, data.liquidity);
    }

    /**
     * @dev sets the default trading fee (in units of PPM)
     */
    function _setDefaultTradingFeePPM(uint32 newDefaultTradingFeePPM) private {
        uint32 prevDefaultTradingFeePPM = _defaultTradingFeePPM;
        if (prevDefaultTradingFeePPM == newDefaultTradingFeePPM) {
            return;
        }

        _defaultTradingFeePPM = newDefaultTradingFeePPM;

        emit DefaultTradingFeePPMUpdated({ prevFeePPM: prevDefaultTradingFeePPM, newFeePPM: newDefaultTradingFeePPM });
    }

    /**
     * @dev returns a storage reference to pool data
     */
    function _poolStorage(Token pool) private view returns (Pool storage) {
        Pool storage data = _poolData[pool];
        if (address(data.poolToken) == address(0)) {
            revert DoesNotExist();
        }

        return data;
    }

    /**
     * @dev calculates base tokens amount
     */
    function _poolTokenToUnderlying(
        uint256 poolTokenAmount,
        uint256 poolTokenSupply,
        uint256 stakedBalance
    ) private pure returns (uint256) {
        if (poolTokenSupply == 0) {
            // if this is the initial liquidity provision - use a one-to-one pool token to base token rate
            if (stakedBalance > 0) {
                revert InvalidStakedBalance();
            }

            return poolTokenAmount;
        }

        return MathEx.mulDivF(poolTokenAmount, stakedBalance, poolTokenSupply);
    }

    /**
     * @dev calculates pool tokens amount
     */
    function _underlyingToPoolToken(
        uint256 tokenAmount,
        uint256 poolTokenSupply,
        uint256 stakedBalance
    ) private pure returns (uint256) {
        if (poolTokenSupply == 0) {
            // if this is the initial liquidity provision - use a one-to-one pool token to base token rate
            if (stakedBalance > 0) {
                revert InvalidStakedBalance();
            }

            return tokenAmount;
        }

        return MathEx.mulDivC(tokenAmount, poolTokenSupply, stakedBalance);
    }

    /**
     * @dev returns the target BNT trading liquidity, and whether or not it needs to be updated
     */
    function _calcTargetBNTTradingLiquidity(
        uint256 tokenReserveAmount,
        uint256 availableFunding,
        uint256 bntTradingLiquidity,
        Fraction memory fundingRate,
        uint256 minLiquidityForTrading
    ) private pure returns (TradingLiquidityAction memory) {
        // calculate the target BNT trading liquidity based on the smaller between the following:
        // - BNT liquidity required to match previously deposited based token liquidity
        // - maximum available BNT trading liquidity (current amount + available funding)
        uint256 targetBNTTradingLiquidity = Math.min(
            MathEx.mulDivF(tokenReserveAmount, fundingRate.n, fundingRate.d),
            bntTradingLiquidity + availableFunding
        );

        // ensure that the target is above the minimum liquidity for trading
        if (targetBNTTradingLiquidity < minLiquidityForTrading) {
            return TradingLiquidityAction({ update: true, newAmount: 0 });
        }

        // calculate the new BNT trading liquidity and cap it by the growth factor
        if (bntTradingLiquidity == 0) {
            // if the current BNT trading liquidity is 0, set it to the minimum liquidity for trading (with an
            // additional buffer so that initial trades will be less likely to trigger disabling of trading)
            uint256 newTargetBNTTradingLiquidity = minLiquidityForTrading * BOOTSTRAPPING_LIQUIDITY_BUFFER_FACTOR;

            // ensure that we're not allocating more than the previously established limits
            if (newTargetBNTTradingLiquidity > targetBNTTradingLiquidity) {
                return TradingLiquidityAction({ update: false, newAmount: 0 });
            }

            targetBNTTradingLiquidity = newTargetBNTTradingLiquidity;
        } else if (targetBNTTradingLiquidity >= bntTradingLiquidity) {
            // if the target is above the current trading liquidity, limit it by factoring the current value up. Please
            // note that if the target is below the current trading liquidity - it will be reduced to it immediately
            targetBNTTradingLiquidity = Math.min(
                targetBNTTradingLiquidity,
                bntTradingLiquidity * LIQUIDITY_GROWTH_FACTOR
            );
        }

        return TradingLiquidityAction({ update: true, newAmount: targetBNTTradingLiquidity });
    }

    /**
     * @dev adjusts the trading liquidity based on the base token vault balance and funding limits
     */
    function _updateTradingLiquidity(
        bytes32 contextId,
        Token pool,
        Pool storage data,
        PoolLiquidity memory liquidity,
        Fraction memory fundingRate,
        uint256 minLiquidityForTrading
    ) private {
        // ensure that the base token reserve isn't empty
        uint256 tokenReserveAmount = pool.balanceOf(address(_masterVault));
        if (tokenReserveAmount == 0) {
            _resetTradingLiquidity(contextId, pool, data, TRADING_STATUS_UPDATE_MIN_LIQUIDITY);

            return;
        }

        if (_poolRateState(liquidity, data.averageRates) == PoolRateState.Unstable) {
            return;
        }

        if (!fundingRate.isPositive()) {
            _resetTradingLiquidity(contextId, pool, data, TRADING_STATUS_UPDATE_MIN_LIQUIDITY);

            return;
        }

        TradingLiquidityAction memory action = _calcTargetBNTTradingLiquidity(
            tokenReserveAmount,
            _bntPool.availableFunding(pool),
            liquidity.bntTradingLiquidity,
            fundingRate,
            minLiquidityForTrading
        );

        if (!action.update) {
            return;
        }

        if (action.newAmount == 0) {
            _resetTradingLiquidity(contextId, pool, data, TRADING_STATUS_UPDATE_MIN_LIQUIDITY);

            return;
        }

        // update funding from the BNT pool
        if (action.newAmount > liquidity.bntTradingLiquidity) {
            _bntPool.requestFunding(contextId, pool, action.newAmount - liquidity.bntTradingLiquidity);
        } else if (action.newAmount < liquidity.bntTradingLiquidity) {
            _bntPool.renounceFunding(contextId, pool, liquidity.bntTradingLiquidity - action.newAmount);
        }

        // calculate the base token trading liquidity based on the new BNT trading liquidity and the effective
        // funding rate (please note that the effective funding rate is always the rate between BNT and the base token)
        uint256 baseTokenTradingLiquidity = MathEx.mulDivF(action.newAmount, fundingRate.d, fundingRate.n);

        // trading liquidity is assumed to never exceed 128 bits (the cast below will revert otherwise)
        PoolLiquidity memory newLiquidity = PoolLiquidity({
            bntTradingLiquidity: SafeCast.toUint128(action.newAmount),
            baseTokenTradingLiquidity: SafeCast.toUint128(baseTokenTradingLiquidity),
            stakedBalance: liquidity.stakedBalance
        });

        // update the liquidity data of the pool
        data.liquidity = newLiquidity;

        _dispatchTradingLiquidityEvents(contextId, pool, data.poolToken.totalSupply(), liquidity, newLiquidity);
    }

    function _dispatchTradingLiquidityEvents(
        bytes32 contextId,
        Token pool,
        PoolLiquidity memory prevLiquidity,
        PoolLiquidity memory newLiquidity
    ) private {
        if (newLiquidity.bntTradingLiquidity != prevLiquidity.bntTradingLiquidity) {
            emit TradingLiquidityUpdated({
                contextId: contextId,
                pool: pool,
                token: Token(address(_bnt)),
                prevLiquidity: prevLiquidity.bntTradingLiquidity,
                newLiquidity: newLiquidity.bntTradingLiquidity
            });
        }

        if (newLiquidity.baseTokenTradingLiquidity != prevLiquidity.baseTokenTradingLiquidity) {
            emit TradingLiquidityUpdated({
                contextId: contextId,
                pool: pool,
                token: pool,
                prevLiquidity: prevLiquidity.baseTokenTradingLiquidity,
                newLiquidity: newLiquidity.baseTokenTradingLiquidity
            });
        }
    }

    function _dispatchTradingLiquidityEvents(
        bytes32 contextId,
        Token pool,
        uint256 poolTokenTotalSupply,
        PoolLiquidity memory prevLiquidity,
        PoolLiquidity memory newLiquidity
    ) private {
        _dispatchTradingLiquidityEvents(contextId, pool, prevLiquidity, newLiquidity);

        if (newLiquidity.stakedBalance != prevLiquidity.stakedBalance) {
            emit TotalLiquidityUpdated({
                contextId: contextId,
                pool: pool,
                liquidity: pool.balanceOf(address(_masterVault)),
                stakedBalance: newLiquidity.stakedBalance,
                poolTokenSupply: poolTokenTotalSupply
            });
        }
    }

    /**
     * @dev resets trading liquidity and renounces any remaining BNT funding
     */
    function _resetTradingLiquidity(
        bytes32 contextId,
        Token pool,
        Pool storage data,
        uint8 reason
    ) private {
        _resetTradingLiquidity(contextId, pool, data, data.liquidity.bntTradingLiquidity, reason);
    }

    /**
     * @dev resets trading liquidity and renounces any remaining BNT funding
     */
    function _resetTradingLiquidity(
        bytes32 contextId,
        Token pool,
        Pool storage data,
        uint256 currentBNTTradingLiquidity,
        uint8 reason
    ) private {
        // reset the network and base token trading liquidities
        data.liquidity.bntTradingLiquidity = 0;
        data.liquidity.baseTokenTradingLiquidity = 0;

        // reset the recent average rage
        data.averageRates = AverageRates({ blockNumber: 0, rate: zeroFraction112(), invRate: zeroFraction112() });

        // ensure that trading is disabled
        if (data.tradingEnabled) {
            data.tradingEnabled = false;

            emit TradingEnabled({ pool: pool, newStatus: false, reason: reason });
        }

        // renounce all network liquidity
        if (currentBNTTradingLiquidity > 0) {
            _bntPool.renounceFunding(contextId, pool, currentBNTTradingLiquidity);
        }
    }

    /**
     * @dev returns initial trading params
     */
    function _initTrade(
        bytes32 contextId,
        Token sourceToken,
        Token targetToken,
        uint256 amount,
        uint256 limit,
        bool bySourceAmount
    ) private view returns (TradeIntermediateResult memory result) {
        // ensure that BNT is either the source or the target token
        bool isSourceBNT = sourceToken.isEqual(_bnt);
        bool isTargetBNT = targetToken.isEqual(_bnt);

        if (isSourceBNT && !isTargetBNT) {
            result.isSourceBNT = true;
            result.pool = targetToken;
        } else if (!isSourceBNT && isTargetBNT) {
            result.isSourceBNT = false;
            result.pool = sourceToken;
        } else {
            // BNT isn't one of the tokens or is both of them
            revert DoesNotExist();
        }

        Pool storage data = _poolStorage(result.pool);

        // verify that trading is enabled
        if (!data.tradingEnabled) {
            revert TradingDisabled();
        }

        result.contextId = contextId;
        result.bySourceAmount = bySourceAmount;

        if (result.bySourceAmount) {
            result.sourceAmount = amount;
        } else {
            result.targetAmount = amount;
        }

        result.limit = limit;
        result.tradingFeePPM = data.tradingFeePPM;

        PoolLiquidity memory liquidity = data.liquidity;
        if (result.isSourceBNT) {
            result.sourceBalance = liquidity.bntTradingLiquidity;
            result.targetBalance = liquidity.baseTokenTradingLiquidity;
        } else {
            result.sourceBalance = liquidity.baseTokenTradingLiquidity;
            result.targetBalance = liquidity.bntTradingLiquidity;
        }

        result.stakedBalance = liquidity.stakedBalance;
    }

    /**
     * @dev returns trade amount and fee by providing the source amount
     */
    function _tradeAmountAndFeeBySourceAmount(
        uint256 sourceBalance,
        uint256 targetBalance,
        uint32 feePPM,
        uint256 sourceAmount
    ) private pure returns (TradeAmountAndTradingFee memory) {
        if (sourceBalance == 0 || targetBalance == 0) {
            revert InsufficientLiquidity();
        }

        uint256 targetAmount = MathEx.mulDivF(targetBalance, sourceAmount, sourceBalance + sourceAmount);
        uint256 tradingFeeAmount = MathEx.mulDivF(targetAmount, feePPM, PPM_RESOLUTION);

        return
            TradeAmountAndTradingFee({ amount: targetAmount - tradingFeeAmount, tradingFeeAmount: tradingFeeAmount });
    }

    /**
     * @dev returns trade amount and fee by providing either the target amount
     */
    function _tradeAmountAndFeeByTargetAmount(
        uint256 sourceBalance,
        uint256 targetBalance,
        uint32 feePPM,
        uint256 targetAmount
    ) private pure returns (TradeAmountAndTradingFee memory) {
        if (sourceBalance == 0) {
            revert InsufficientLiquidity();
        }

        uint256 tradingFeeAmount = MathEx.mulDivF(targetAmount, feePPM, PPM_RESOLUTION - feePPM);
        uint256 fullTargetAmount = targetAmount + tradingFeeAmount;
        uint256 sourceAmount = MathEx.mulDivF(sourceBalance, fullTargetAmount, targetBalance - fullTargetAmount);

        return TradeAmountAndTradingFee({ amount: sourceAmount, tradingFeeAmount: tradingFeeAmount });
    }

    /**
     * @dev processes a trade by providing either the source or the target amount and updates the in-memory intermediate
     * result
     */
    function _processTrade(TradeIntermediateResult memory result) private view {
        TradeAmountAndTradingFee memory tradeAmountAndFee;

        if (result.bySourceAmount) {
            tradeAmountAndFee = _tradeAmountAndFeeBySourceAmount(
                result.sourceBalance,
                result.targetBalance,
                result.tradingFeePPM,
                result.sourceAmount
            );

            result.targetAmount = tradeAmountAndFee.amount;

            // ensure that the target amount is above the requested minimum return amount
            if (result.targetAmount < result.limit) {
                revert InsufficientTargetAmount();
            }
        } else {
            tradeAmountAndFee = _tradeAmountAndFeeByTargetAmount(
                result.sourceBalance,
                result.targetBalance,
                result.tradingFeePPM,
                result.targetAmount
            );

            result.sourceAmount = tradeAmountAndFee.amount;

            // ensure that the user has provided enough tokens to make the trade
            if (result.sourceAmount == 0 || result.sourceAmount > result.limit) {
                revert InsufficientSourceAmount();
            }
        }

        result.tradingFeeAmount = tradeAmountAndFee.tradingFeeAmount;

        // sync the trading and staked balance
        result.sourceBalance += result.sourceAmount;
        result.targetBalance -= result.targetAmount;

        if (result.isSourceBNT) {
            result.stakedBalance += result.tradingFeeAmount;
        }

        _processNetworkFee(result);
    }

    /**
     * @dev processes the network fee and updates the in-memory intermediate result
     */
    function _processNetworkFee(TradeIntermediateResult memory result) private view {
        uint32 networkFeePPM = _networkSettings.networkFeePPM();
        if (networkFeePPM == 0) {
            return;
        }

        // calculate the target network fee amount
        uint256 targetNetworkFeeAmount = MathEx.mulDivF(result.tradingFeeAmount, networkFeePPM, PPM_RESOLUTION);

        // update the target balance (but don't deduct it from the full trading fee amount)
        result.targetBalance -= targetNetworkFeeAmount;

        if (!result.isSourceBNT) {
            result.networkFeeAmount = targetNetworkFeeAmount;

            return;
        }

        // trade the network fee (taken from the base token) to BNT
        result.networkFeeAmount = _tradeAmountAndFeeBySourceAmount(
            result.targetBalance,
            result.sourceBalance,
            0,
            targetNetworkFeeAmount
        ).amount;

        // since we have received the network fee in base tokens and have traded them for BNT (so that the network fee
        // is always kept in BNT), we'd need to adapt the trading liquidity and the staked balance accordingly
        result.targetBalance += targetNetworkFeeAmount;
        result.sourceBalance -= result.networkFeeAmount;
        result.stakedBalance -= targetNetworkFeeAmount;
    }

    /**
     * @dev performs a trade
     */
    function _performTrade(TradeIntermediateResult memory result) private {
        Pool storage data = _poolData[result.pool];
        PoolLiquidity memory prevLiquidity = data.liquidity;

        // update the recent average rate
        _updateAverageRates(
            data,
            Fraction({ n: prevLiquidity.bntTradingLiquidity, d: prevLiquidity.baseTokenTradingLiquidity })
        );

        _processTrade(result);

        // trading liquidity is assumed to never exceed 128 bits (the cast below will revert otherwise)
        PoolLiquidity memory newLiquidity = PoolLiquidity({
            bntTradingLiquidity: SafeCast.toUint128(result.isSourceBNT ? result.sourceBalance : result.targetBalance),
            baseTokenTradingLiquidity: SafeCast.toUint128(
                result.isSourceBNT ? result.targetBalance : result.sourceBalance
            ),
            stakedBalance: result.stakedBalance
        });

        _dispatchTradingLiquidityEvents(result.contextId, result.pool, prevLiquidity, newLiquidity);

        // update the liquidity data of the pool
        data.liquidity = newLiquidity;
    }

    /**
     * @dev returns the state of a pool's rate
     */
    function _poolRateState(PoolLiquidity memory liquidity, AverageRates memory averageRates)
        internal
        view
        returns (PoolRateState)
    {
        Fraction memory spotRate = Fraction({
            n: liquidity.bntTradingLiquidity,
            d: liquidity.baseTokenTradingLiquidity
        });

        Fraction112 memory rate = averageRates.rate;

        if (!spotRate.isPositive() || !rate.isPositive()) {
            return PoolRateState.Uninitialized;
        }

        Fraction memory invSpotRate = spotRate.inverse();
        Fraction112 memory invRate = averageRates.invRate;

        if (!invSpotRate.isPositive() || !invRate.isPositive()) {
            return PoolRateState.Uninitialized;
        }

        if (averageRates.blockNumber != _blockNumber()) {
            rate = _calcAverageRate(rate, spotRate);
            invRate = _calcAverageRate(invRate, invSpotRate);
        }

        if (
            MathEx.isInRange(rate.fromFraction112(), spotRate, RATE_MAX_DEVIATION_PPM) &&
            MathEx.isInRange(invRate.fromFraction112(), invSpotRate, RATE_MAX_DEVIATION_PPM)
        ) {
            return PoolRateState.Stable;
        }

        return PoolRateState.Unstable;
    }

    /**
     * @dev updates the average rates
     */
    function _updateAverageRates(Pool storage data, Fraction memory spotRate) private {
        uint32 blockNumber = _blockNumber();

        if (data.averageRates.blockNumber != blockNumber) {
            data.averageRates = AverageRates({
                blockNumber: blockNumber,
                rate: _calcAverageRate(data.averageRates.rate, spotRate),
                invRate: _calcAverageRate(data.averageRates.invRate, spotRate.inverse())
            });
        }
    }

    /**
     * @dev calculates the average rate
     */
    function _calcAverageRate(Fraction112 memory averageRate, Fraction memory rate)
        private
        pure
        returns (Fraction112 memory)
    {
        if (rate.n * averageRate.d == rate.d * averageRate.n) {
            return averageRate;
        }

        return
            MathEx
                .weightedAverage(averageRate.fromFraction112(), rate, EMA_AVERAGE_RATE_WEIGHT, EMA_SPOT_RATE_WEIGHT)
                .toFraction112();
    }

    /**
     * @dev verifies if the provided rate is valid
     */
    function _validRate(Fraction memory rate) internal pure {
        if (!rate.isPositive()) {
            revert InvalidRate();
        }
    }
}
