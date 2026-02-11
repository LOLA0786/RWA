const axios = require("axios");

let totalRequests = 0;
let totalErrors = 0;
let totalLatency = 0;

const SLA_MAX_LATENCY_MS = 500;
const SLA_MAX_ERROR_RATE = 0.01;

async function sendSlackAlert(message) {
  if (!process.env.SLACK_WEBHOOK_URL) return;

  try {
    await axios.post(process.env.SLACK_WEBHOOK_URL, {
      text: `🚨 SLA ALERT: ${message}`
    });
  } catch (err) {
    console.error("Slack alert failed:", err.message);
  }
}

function recordRequest(latency, isError) {
  totalRequests++;
  totalLatency += latency;
  if (isError) totalErrors++;

  evaluateSLA();
}

function evaluateSLA() {
  const avgLatency = totalLatency / totalRequests;
  const errorRate = totalErrors / totalRequests;

  if (avgLatency > SLA_MAX_LATENCY_MS) {
    console.error("⚠ SLA BREACH: Latency exceeded");
    sendSlackAlert("Latency threshold exceeded");
  }

  if (errorRate > SLA_MAX_ERROR_RATE) {
    console.error("⚠ SLA BREACH: Error rate exceeded");
    sendSlackAlert("Error rate threshold exceeded");
  }
}

function getStats() {
  return {
    totalRequests,
    totalErrors,
    avgLatency: totalRequests ? totalLatency / totalRequests : 0,
    errorRate: totalRequests ? totalErrors / totalRequests : 0
  };
}

module.exports = { recordRequest, getStats };
