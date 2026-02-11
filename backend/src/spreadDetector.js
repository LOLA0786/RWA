/**
 * SpreadDetector
 * ──────────────
 * Reads Chainlink Data Feed prices for the same RWA token on two chains.
 * Computes spread in basis points.
 * Returns structured result for monitor and bridge trigger.
 */

import { ethers } from "ethers";

// Minimal ABI for Chainlink AggregatorV3Interface
const FEED_ABI = [
  "function latestRoundData() external view returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)",
  "function decimals() external view returns (uint8)",
  "function description() external view returns (string)",
];

export class SpreadDetector {
  /**
   * @param {Object} chainConfigs  { chainName: { rpcUrl, feedAddresses: { symbol: address } } }
   */
  constructor(chainConfigs) {
    this.providers = {};
    for (const [chainName, cfg] of Object.entries(chainConfigs)) {
      this.providers[chainName] = new ethers.JsonRpcProvider(cfg.rpcUrl);
    }
  }

  /**
   * Check spread for a monitored pair.
   * @param {Object} pair
   *   pair.symbol         — e.g. "OUSG"
   *   pair.srcChain       — chain name key
   *   pair.destChain      — chain name key
   *   pair.srcFeedAddr    — Data Feed address on source
   *   pair.destFeedAddr   — Data Feed address on dest
   *   pair.destChainSelector — CCIP selector for dest
   * @returns {Object} { srcPrice, destPrice, spreadBps, availableLiquidity }
   */
  async checkSpread(pair) {
    const [srcPrice, destPrice] = await Promise.all([
      this._fetchPrice(pair.srcChain, pair.srcFeedAddr),
      this._fetchPrice(pair.destChain, pair.destFeedAddr),
    ]);

    const spreadBps = destPrice > srcPrice
      ? ((destPrice - srcPrice) / srcPrice) * 10_000
      : 0;

    // Estimate available liquidity from hub contract balance
    const availableLiquidity = await this._getAvailableLiquidity(pair);

    return {
      srcPrice,
      destPrice,
      spreadBps,
      availableLiquidity,
      timestamp: Date.now(),
      pair,
    };
  }

  /**
   * Fetch latest price from a Chainlink feed.
   * @returns {number} Price in USD (float)
   */
  async _fetchPrice(chainName, feedAddress) {
    const provider = this.providers[chainName];
    if (!provider) throw new Error(`No provider for chain: ${chainName}`);

    const feed = new ethers.Contract(feedAddress, FEED_ABI, provider);

    const [roundData, decimals] = await Promise.all([
      feed.latestRoundData(),
      feed.decimals(),
    ]);

    const { answer, updatedAt, roundId, answeredInRound } = roundData;

    // Staleness check: reject if > 1 hour old
    const age = Math.floor(Date.now() / 1000) - Number(updatedAt);
    if (age > 3600) {
      throw new Error(`Stale price on ${chainName}/${feedAddress} — ${age}s old`);
    }

    if (answeredInRound < roundId) {
      throw new Error(`Stale round on ${chainName}/${feedAddress}`);
    }

    if (answer <= 0n) {
      throw new Error(`Invalid price (${answer}) on ${chainName}/${feedAddress}`);
    }

    // Convert to float with correct decimals
    return Number(ethers.formatUnits(answer, decimals));
  }

  /**
   * Get how much liquidity is available to bridge.
   * Reads vault balance from hub contract.
   */
  async _getAvailableLiquidity(pair) {
    try {
      const hubAddress = process.env[`RWA_LIQUIDITY_HUB_${pair.srcChain.toUpperCase()}`];
      if (!hubAddress) return 0;

      const provider = this.providers[pair.srcChain];
      const erc20 = new ethers.Contract(
        pair.srcTokenAddress,
        ["function balanceOf(address) view returns (uint256)", "function decimals() view returns (uint8)"],
        provider
      );
      const [balance, decimals] = await Promise.all([
        erc20.balanceOf(hubAddress),
        erc20.decimals(),
      ]);
      // Return as USD equivalent (approximate, using srcPrice)
      const tokenAmount = Number(ethers.formatUnits(balance, decimals));
      return tokenAmount; // multiply by price in caller if needed
    } catch {
      return 0;
    }
  }
}
