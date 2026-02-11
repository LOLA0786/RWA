const express = require("express");
const bodyParser = require("body-parser");
const config = require("../core/config");
const { processSettlement } = require("../settlement/settlementKernel");
const { logEvent } = require("../monitoring/auditLogger");

const app = express();
app.use(bodyParser.json());

function auth(req, res, next) {
  if (req.headers["x-api-key"] !== config.INSTITUTIONAL_API_KEY) {
    return res.status(403).json({ error: "Unauthorized" });
  }
  next();
}

app.post("/settlement", auth, async (req, res) => {
  const result = await processSettlement(req.body);

  logEvent({
    type: "SETTLEMENT_REQUEST",
    payload: req.body,
    result,
  });

  res.json(result);
});

app.get("/health", (req, res) => {
  res.json({ status: "OK" });
});

app.listen(config.PORT, () => {
  console.log(`Institutional OS running on port ${config.PORT}`);
});
