/**
 * AlertEngine
 * ───────────
 * Sends notifications to Slack and/or Telegram when:
 *  - Spread opportunity detected
 *  - Bridge executed
 *  - Error occurred
 *  - Price data is stale
 */

export class AlertEngine {
  constructor() {
    this.slackWebhook = process.env.SLACK_WEBHOOK_URL;
    this.tgToken      = process.env.TELEGRAM_BOT_TOKEN;
    this.tgChatId     = process.env.TELEGRAM_CHAT_ID;
  }

  /**
   * @param {Object} event
   *   event.type    — "BRIDGE_EXECUTED" | "SPREAD_DETECTED_LOW_LIQUIDITY" | "ERROR"
   *   event.pair    — pair config
   *   event.result  — spread result (optional)
   *   event.txHash  — (optional)
   *   event.error   — (optional)
   */
  async send(event) {
    const msg = this._format(event);
    if (!msg) return;

    await Promise.allSettled([
      this._sendSlack(msg),
      this._sendTelegram(msg),
    ]);
  }

  _format(event) {
    switch (event.type) {
      case "BRIDGE_EXECUTED":
        return [
          `⚡ *RWA Bridge Executed*`,
          `Token: \`${event.pair.symbol}\``,
          `Route: ${event.pair.srcChain} → ${event.pair.destChain}`,
          `Spread: *${event.result.spreadBps.toFixed(1)} bps*`,
          `Src: $${event.result.srcPrice.toFixed(4)} | Dst: $${event.result.destPrice.toFixed(4)}`,
          `Tx: \`${event.txHash}\``,
        ].join("\n");

      case "SPREAD_DETECTED_LOW_LIQUIDITY":
        return [
          `📊 *Spread Detected (Low Liquidity)*`,
          `Token: \`${event.pair.symbol}\``,
          `Spread: ${event.result.spreadBps.toFixed(1)} bps`,
          `Available: $${event.result.availableLiquidity.toFixed(0)} (below minimum)`,
        ].join("\n");

      case "ERROR":
        return [
          `❌ *Monitor Error*`,
          `Pair: \`${event.pair?.symbol || "unknown"}\``,
          `Error: ${event.error}`,
        ].join("\n");

      default:
        return null;
    }
  }

  async _sendSlack(text) {
    if (!this.slackWebhook) return;
    try {
      await fetch(this.slackWebhook, {
        method:  "POST",
        headers: { "Content-Type": "application/json" },
        body:    JSON.stringify({ text }),
      });
    } catch (err) {
      console.error("Slack alert failed:", err.message);
    }
  }

  async _sendTelegram(text) {
    if (!this.tgToken || !this.tgChatId) return;
    try {
      const url = `https://api.telegram.org/bot${this.tgToken}/sendMessage`;
      await fetch(url, {
        method:  "POST",
        headers: { "Content-Type": "application/json" },
        body:    JSON.stringify({
          chat_id:    this.tgChatId,
          text,
          parse_mode: "Markdown",
        }),
      });
    } catch (err) {
      console.error("Telegram alert failed:", err.message);
    }
  }
}
