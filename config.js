/**
 * config.js
 * ─────────
 * Define chains, RPC endpoints, and the pairs to monitor.
 * Add new chains or tokens here — no code changes needed.
 */

export const CHAINS = {
  sepolia: {
    rpcUrl: process.env.SEPOLIA_RPC_URL,
    chainId: 11155111,
    ccipSelector: "16015286601757825753",
    feedAddresses: {
      // Token symbol => Chainlink Data Feed address
      // Replace with real feed addresses for your tokens
      OUSG:   "0x0000000000000000000000000000000000000001", // placeholder
      BUIDL:  "0x0000000000000000000000000000000000000002", // placeholder
      USDC:   "0xA2F78ab2355fe2f984D808B5CeE7FD0A93D5270E", // Sepolia USDC/USD
    },
  },
  mumbai: {
    rpcUrl: process.env.MUMBAI_RPC_URL,
    chainId: 80001,
    ccipSelector: "12532609583862916517",
    feedAddresses: {
      OUSG:  "0x0000000000000000000000000000000000000003", // placeholder
      BUIDL: "0x0000000000000000000000000000000000000004", // placeholder
      USDC:  "0x572dDec9087154dC5dfBB1546Bb62713147e0Ab0", // Mumbai USDC/USD
    },
  },
  fuji: {
    rpcUrl: process.env.AVALANCHE_FUJI_RPC_URL,
    chainId: 43113,
    ccipSelector: "14767482510784806043",
    feedAddresses: {
      OUSG:  "0x0000000000000000000000000000000000000005", // placeholder
      USDC:  "0x7898AcCC83587C3C55116c5230C17a6Cd9C71bad",
    },
  },
};

/**
 * Pairs to monitor for cross-chain spread.
 * Each pair = one directional route (srcChain → destChain).
 * Add the reverse pair separately if you want bidirectional monitoring.
 */
export const MONITORED_PAIRS = [
  {
    symbol:            "OUSG",
    srcChain:          "sepolia",
    destChain:         "mumbai",
    destChainSelector: BigInt("12532609583862916517"),
    srcFeedAddr:       CHAINS.sepolia.feedAddresses.OUSG,
    destFeedAddr:      CHAINS.mumbai.feedAddresses.OUSG,
    srcTokenAddress:   process.env.OUSG_TOKEN_SEPOLIA  || "0x0000000000000000000000000000000000000001",
    destTokenAddress:  process.env.OUSG_TOKEN_MUMBAI   || "0x0000000000000000000000000000000000000003",
  },
  {
    symbol:            "OUSG",
    srcChain:          "mumbai",
    destChain:         "sepolia",
    destChainSelector: BigInt("16015286601757825753"),
    srcFeedAddr:       CHAINS.mumbai.feedAddresses.OUSG,
    destFeedAddr:      CHAINS.sepolia.feedAddresses.OUSG,
    srcTokenAddress:   process.env.OUSG_TOKEN_MUMBAI   || "0x0000000000000000000000000000000000000003",
    destTokenAddress:  process.env.OUSG_TOKEN_SEPOLIA  || "0x0000000000000000000000000000000000000001",
  },
  // ── Add more pairs here ───────────────────────────────────────
  // {
  //   symbol:           "BUIDL",
  //   srcChain:         "sepolia",
  //   destChain:        "fuji",
  //   ...
  // },
];

export const CONFIG = {
  spreadThresholdBps: parseInt(process.env.SPREAD_THRESHOLD_BPS) || 50,
  pollIntervalMs:     parseInt(process.env.POLL_INTERVAL_MS)     || 30_000,
  minArbitrageUSD:    parseInt(process.env.MIN_ARBITRAGE_AMOUNT_USD) || 1_000,
  protocolFeeBps:     parseInt(process.env.PROTOCOL_FEE_BPS)     || 50,
};
