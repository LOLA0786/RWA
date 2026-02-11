// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title SpreadOracle
 * @notice Reads Chainlink Data Feeds for RWA token prices and computes
 *         the spread (in bps) between source chain price and the
 *         registered destination chain price feed.
 *
 * @dev In production, destination prices come from a cross-chain price
 *      aggregation service or a Chainlink Functions callback that fetches
 *      the price from the destination chain. For v0.1 we store a cached
 *      destination price that the backend updates via Chainlink Functions.
 */
contract SpreadOracle is Ownable {

    // ── State ─────────────────────────────────────────────────────

    struct PriceFeedConfig {
        AggregatorV3Interface feed;
        uint8  decimals;
        uint256 stalenessThreshold; // seconds before price is considered stale
    }

    /// @dev token => local price feed
    mapping(address => PriceFeedConfig) public localFeeds;

    /// @dev token => destChainSelector => cached destination price (scaled to 1e18)
    mapping(address => mapping(uint64 => uint256)) public cachedDestPrices;

    /// @dev token => destChainSelector => last update timestamp
    mapping(address => mapping(uint64 => uint256)) public lastUpdated;

    /// @dev Maximum age of cached destination price (default 5 min)
    uint256 public destPriceStalenessThreshold = 5 minutes;

    // ── Events ────────────────────────────────────────────────────
    event DestPriceUpdated(address indexed token, uint64 destChain, uint256 price, uint256 timestamp);
    event FeedRegistered(address indexed token, address feed);

    // ── Errors ────────────────────────────────────────────────────
    error NoFeedForToken(address token);
    error StalePriceData(address token, uint256 updatedAt, uint256 threshold);
    error StaleDestPrice(address token, uint64 destChain, uint256 age);
    error ZeroPrice();

    // ── Constructor ───────────────────────────────────────────────
    constructor() Ownable(msg.sender) {}

    // ── Core: Spread Calculation ──────────────────────────────────

    /**
     * @notice Get spread in basis points between local and destination price.
     * @param token             Local RWA token address
     * @param destChainSelector Destination chain CCIP selector
     * @return spreadBps        Spread in basis points. 100 = 1%.
     *                          Returns 0 if dest price >= local price (no arb opportunity).
     */
    function getSpreadBps(
        address token,
        uint64  destChainSelector
    ) external view returns (uint256 spreadBps) {
        uint256 localPrice = _getLocalPrice(token);
        uint256 destPrice  = _getDestPrice(token, destChainSelector);

        if (destPrice <= localPrice) return 0;

        // spread = (destPrice - localPrice) / localPrice * 10_000
        spreadBps = ((destPrice - localPrice) * 10_000) / localPrice;
    }

    /**
     * @notice Get both prices and the spread in one call (for UIs).
     */
    function getSpreadDetails(
        address token,
        uint64  destChainSelector
    ) external view returns (
        uint256 localPriceUSD,
        uint256 destPriceUSD,
        uint256 spreadBps
    ) {
        localPriceUSD = _getLocalPrice(token);
        destPriceUSD  = _getDestPrice(token, destChainSelector);

        if (destPriceUSD > localPriceUSD) {
            spreadBps = ((destPriceUSD - localPriceUSD) * 10_000) / localPriceUSD;
        }
    }

    // ── Admin ─────────────────────────────────────────────────────

    function registerLocalFeed(
        address token,
        address feed,
        uint8   decimals,
        uint256 stalenessThreshold
    ) external onlyOwner {
        localFeeds[token] = PriceFeedConfig({
            feed: AggregatorV3Interface(feed),
            decimals: decimals,
            stalenessThreshold: stalenessThreshold
        });
        emit FeedRegistered(token, feed);
    }

    /**
     * @notice Called by Chainlink Functions callback or backend oracle
     *         to update the cached destination price.
     * @param price Price in 1e18 USD terms
     */
    function updateDestPrice(
        address token,
        uint64  destChainSelector,
        uint256 price
    ) external onlyOwner {
        if (price == 0) revert ZeroPrice();
        cachedDestPrices[token][destChainSelector] = price;
        lastUpdated[token][destChainSelector]      = block.timestamp;
        emit DestPriceUpdated(token, destChainSelector, price, block.timestamp);
    }

    function setDestPriceStalenessThreshold(uint256 threshold) external onlyOwner {
        destPriceStalenessThreshold = threshold;
    }

    // ── Internal ──────────────────────────────────────────────────

    function _getLocalPrice(address token) internal view returns (uint256) {
        PriceFeedConfig memory cfg = localFeeds[token];
        if (address(cfg.feed) == address(0)) revert NoFeedForToken(token);

        (
            uint80  roundId,
            int256  answer,
            ,
            uint256 updatedAt,
            uint80  answeredInRound
        ) = cfg.feed.latestRoundData();

        require(answeredInRound >= roundId, "Stale round");
        if (block.timestamp - updatedAt > cfg.stalenessThreshold) {
            revert StalePriceData(token, updatedAt, cfg.stalenessThreshold);
        }
        if (answer <= 0) revert ZeroPrice();

        // Normalise to 1e18
        uint256 normalised = uint256(answer);
        if (cfg.decimals < 18) {
            normalised = normalised * (10 ** (18 - cfg.decimals));
        } else if (cfg.decimals > 18) {
            normalised = normalised / (10 ** (cfg.decimals - 18));
        }
        return normalised;
    }

    function _getDestPrice(address token, uint64 destChainSelector) internal view returns (uint256) {
        uint256 price     = cachedDestPrices[token][destChainSelector];
        uint256 updated   = lastUpdated[token][destChainSelector];
        uint256 age       = block.timestamp - updated;

        if (price == 0 || age > destPriceStalenessThreshold) {
            revert StaleDestPrice(token, destChainSelector, age);
        }
        return price;
    }
}
