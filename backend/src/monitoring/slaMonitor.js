let totalRequests = 0;
let totalErrors = 0;
let totalLatency = 0;

const SLA_MAX_LATENCY_MS = 500;
const SLA_MAX_ERROR_RATE = 0.01; // 1%

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
  }

  if (errorRate > SLA_MAX_ERROR_RATE) {
    console.error("⚠ SLA BREACH: Error rate exceeded");
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
