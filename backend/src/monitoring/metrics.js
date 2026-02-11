const client = require("prom-client");

const register = new client.Registry();
client.collectDefaultMetrics({ register });

const requestCounter = new client.Counter({
  name: "rwa_requests_total",
  help: "Total API requests"
});

const errorCounter = new client.Counter({
  name: "rwa_errors_total",
  help: "Total API errors"
});

const latencyHistogram = new client.Histogram({
  name: "rwa_request_latency_ms",
  help: "Request latency",
  buckets: [50, 100, 200, 500, 1000]
});

register.registerMetric(requestCounter);
register.registerMetric(errorCounter);
register.registerMetric(latencyHistogram);

module.exports = {
  register,
  requestCounter,
  errorCounter,
  latencyHistogram
};
