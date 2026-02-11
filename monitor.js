#!/usr/bin/env node
/**
 * RWA Cross-Chain Spread Monitor
 * ─────────────────────────────
 * Polls Chainlink Data Feeds across chains.
 * Detects when spread > threshold.
 * Triggers bridge on RWALiquidityHub.
 * Alerts via Slack/Telegram.
 *
 * Run: node src/monitor.js
 *      or: npm run monitor
 */

import "dotenv/config";
import { SpreadDetector } from "./spreadDetector.js";
import { BridgeTrigger }  from "./bridgeTrigger.js";
import { AlertEngine }    from "./alertEngine.js";
import { MONITORED_PAIRS, CHAINS }    from "../config/config.js";

const POLL_MS = parseInt(process.env.POLL_INTERVAL_MS) || 30_000;

// ── Initialise modules ─────────────────────────────────────────
const detector = new SpreadDetector(CHAINS);
const trigger  = new BridgeTrigger();
const alerts   = new AlertEngine();

let iteration = 0;

// ── Main loop ──────────────────────────────────────────────────
async function tick() {
  iteration++;
  const ts = new Date().toISOString();
  console.log(`\n[${ts}] ── Tick #${iteration} ─────────────────────────`);

  for (const pair of MONITORED_PAIRS) {
    try {
      const result = await detector.checkSpread(pair);

      console.log(
        `  ${pair.symbol} | ${pair.srcChain} → ${pair.destChain}` +
        ` | Src: $${result.srcPrice.toFixed(4)}` +
        ` | Dst: $${result.destPrice.toFixed(4)}` +
        ` | Spread: ${result.spreadBps.toFixed(1)} bps`
      );

      const threshold = parseInt(process.env.SPREAD_THRESHOLD_BPS) || 50;

      if (result.spreadBps >= threshold) {
        console.log(`  ⚡ SPREAD OPPORTUNITY DETECTED — ${result.spreadBps.toFixed(1)} bps`);

        // Only auto-trigger if amount above minimum
        const minUSD = parseInt(process.env.MIN_ARBITRAGE_AMOUNT_USD) || 1000;
        if (result.availableLiquidity >= minUSD) {
          const txHash = await trigger.executeBridge(pair, result);
          console.log(`  ✅ Bridge triggered: ${txHash}`);
          await alerts.send({
            type:      "BRIDGE_EXECUTED",
            pair,
            result,
            txHash,
          });
        } else {
          console.log(`  ⚠️  Spread found but liquidity below minimum ($${minUSD})`);
          await alerts.send({
            type:   "SPREAD_DETECTED_LOW_LIQUIDITY",
            pair,
            result,
          });
        }
      }

    } catch (err) {
      console.error(`  ❌ Error checking ${pair.symbol}: ${err.message}`);
      await alerts.send({ type: "ERROR", pair, error: err.message });
    }
  }
}

// ── Start ──────────────────────────────────────────────────────
console.log("🚀 RWA Liquidity Monitor starting...");
console.log(`   Polling every ${POLL_MS / 1000}s`);
console.log(`   Spread threshold: ${process.env.SPREAD_THRESHOLD_BPS || 50} bps`);
console.log(`   Monitoring ${MONITORED_PAIRS.length} pairs\n`);

// Run immediately, then on interval
tick();
setInterval(tick, POLL_MS);
