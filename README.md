# ⛓ RWA Cross-Chain Liquidity Aggregator

> Unify fragmented Real-World Asset markets across EVM chains using Chainlink CCIP + Data Feeds.
> Detect price spreads, trigger automated arbitrage bridges, and give institutions a single liquidity surface.

```
Ethereum ──┐
Polygon  ──┼──► Chainlink CCIP ──► Unified Liquidity Pool ──► Swap / Arbitrage / Bridge
Avalanche──┘
```

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     OFF-CHAIN BACKEND                           │
│  SpreadDetector → ArbitrageRouter → BridgeQueue → AlertEngine   │
└────────────────────────┬────────────────────────────────────────┘
                         │ price feeds + spread signals
┌────────────────────────▼────────────────────────────────────────┐
│                   SMART CONTRACTS (Foundry)                     │
│  RWALiquidityHub.sol  ←→  CCIPBridgeAdapter.sol                 │
│  SpreadOracle.sol     ←→  RWAVaultManager.sol                   │
└────────────────────────┬────────────────────────────────────────┘
                         │ CCIP messages
┌────────────────────────▼────────────────────────────────────────┐
│                    CHAINLINK LAYER                              │
│   Data Feeds (price)  +  CCIP (cross-chain)  +  Functions      │
└─────────────────────────────────────────────────────────────────┘
```

---

## Stack

| Layer | Tech |
|-------|------|
| Smart Contracts | Solidity 0.8.24, Foundry |
| Cross-Chain | Chainlink CCIP |
| Price Oracles | Chainlink Data Feeds |
| Off-chain Compute | Chainlink Functions (JS) |
| Backend | Node.js + Ethers.js v6 |
| Frontend | React + Vite + wagmi/viem |
| Testing | Forge tests + Hardhat fork tests |

---

## Quickstart

### Prerequisites

```bash
# Install Foundry
curl -L https://foundry.paradigm.xyz | bash
foundryup

# Install Node.js >= 18
node --version

# Install dependencies
npm install
```

### 1. Clone & Install

```bash
git clone https://github.com/YOUR_USERNAME/rwa-liquidity-aggregator
cd rwa-liquidity-aggregator
npm install
cd contracts && forge install
```

### 2. Environment Setup

```bash
cp .env.example .env
# Fill in your keys (see .env.example for all required vars)
```

### 3. Run Tests

```bash
# Smart contract tests
cd contracts
forge test -vvv

# Backend unit tests
cd ..
npm test
```

### 4. Deploy to Testnet (Sepolia + Mumbai)

```bash
npm run deploy:sepolia
npm run deploy:mumbai
npm run setup:ccip   # registers chains on both deployments
```

### 5. Run the Backend Monitor

```bash
npm run monitor
# Starts watching for cross-chain spread opportunities
# Console output: detected spreads, bridge triggers, tx hashes
```

### 6. Start Frontend

```bash
npm run dev
# Open http://localhost:5173
```

---

## How It Works

### Spread Detection
The backend polls Chainlink Data Feeds for the same RWA token price across chains every 30s.
When spread > configured threshold (default: 0.5%), it triggers the bridge logic.

### CCIP Bridge Flow
```
Chain A: RWAVaultManager.lockAndSend(amount, tokenAddress, chainSelector)
    → locks tokens in vault
    → sends CCIP message with payload
Chain B: CCIPBridgeAdapter.ccipReceive(message)
    → validates sender + chain
    → releases equivalent tokens from vault
    → emits ArbitrageCompleted event
```

### Fee Model
- 0.5% on every bridged swap (configurable per asset)
- Fees accumulate in FeeCollector.sol
- Claimable by protocol owner

---

## Project Structure

```
rwa-liquidity-aggregator/
├── contracts/
│   ├── src/
│   │   ├── RWALiquidityHub.sol      # Main entry point
│   │   ├── CCIPBridgeAdapter.sol    # Handles CCIP send/receive
│   │   ├── SpreadOracle.sol         # Reads + compares Data Feeds
│   │   ├── RWAVaultManager.sol      # Lock/release token vaults
│   │   └── FeeCollector.sol         # Protocol fee accumulator
│   ├── test/
│   │   ├── RWALiquidityHub.t.sol
│   │   └── CCIPBridgeAdapter.t.sol
│   └── script/
│       ├── Deploy.s.sol
│       └── SetupCCIP.s.sol
├── backend/
│   └── src/
│       ├── monitor.js               # Main spread monitor loop
│       ├── spreadDetector.js        # Price comparison logic
│       ├── bridgeTrigger.js         # Calls contracts when spread found
│       └── alertEngine.js           # Slack/Telegram/webhook alerts
├── frontend/
│   └── src/
│       ├── components/
│       │   ├── SpreadDashboard.jsx  # Live spread visualisation
│       │   ├── BridgePanel.jsx      # Manual bridge UI
│       │   └── ArbitrageLog.jsx     # Historical tx log
│       └── hooks/
│           ├── useSpreadData.js     # Polls backend API
│           └── useCCIPStatus.js     # Tracks in-flight bridges
├── scripts/
│   ├── deploy-sepolia.js
│   └── deploy-mumbai.js
└── .github/workflows/
    └── ci.yml                       # forge test + npm test on PR
```

---

## Supported Asset Classes (v0.1)

- Tokenized US T-Bills (e.g. OUSG, BUIDL)
- Tokenized Money Market Funds
- Tokenized Real Estate (ERC-20 fractions)
- Commodity tokens (gold, silver)

---

## Roadmap

- [ ] v0.1 — Sepolia/Mumbai testnet, manual bridge, spread detection
- [ ] v0.2 — Automated arbitrage triggers, fee collection
- [ ] v0.3 — Avalanche + Arbitrum support via CCIP
- [ ] v0.4 — Institutional API, Chainlink Functions for off-chain settlement confirmation
- [ ] v1.0 — Mainnet, audit, fee-switch on

---

## License

MIT
