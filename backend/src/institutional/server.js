const express = require("express");
require("dotenv").config();

const { checkCompliance } = require("../compliance/complianceEngine");
const { getReserveStatus, mint, burn } = require("../settlement/reserveEngine");
const { appendAudit, getAudits } = require("../monitoring/auditStore");
const { recordRequest, getStats } = require("../monitoring/slaMonitor");

const app = express();
app.use(express.json());

function auth(req, res, next) {
  if (req.headers["x-api-key"] !== process.env.INSTITUTIONAL_API_KEY) {
    return res.status(403).json({ error: "Unauthorized" });
  }
  next();
}

function wrapHandler(handler) {
  return async (req, res) => {
    const start = Date.now();
    try {
      await handler(req, res);
      recordRequest(Date.now() - start, false);
    } catch (err) {
      recordRequest(Date.now() - start, true);
      console.error(err);
      res.status(500).json({ error: "Internal error" });
    }
  };
}

app.post("/stablecoin/mint", auth, wrapHandler((req, res) => {
  const { address, amount } = req.body;

  const compliance = checkCompliance(address);
  const reserve = getReserveStatus();

  if (!compliance.allowed) {
    return res.json({ status: "BLOCKED", reason: compliance.reason });
  }

  if (!reserve.fullyBacked) {
    return res.json({ status: "BLOCKED", reason: "Reserve violation" });
  }

  mint(amount);

  const audit = appendAudit({
    type: "MINT",
    address,
    amount,
    timestamp: new Date().toISOString()
  });

  res.json({ status: "APPROVED", audit });
}));

app.get("/stablecoin/reserve", auth, wrapHandler((req, res) => {
  res.json(getReserveStatus());
}));

app.get("/stablecoin/audits", auth, wrapHandler((req, res) => {
  res.json(getAudits());
}));

app.get("/sla", (req, res) => {
  res.json(getStats());
});

app.listen(process.env.PORT || 3000, () => {
  console.log("Stablecoin Settlement Kernel running");
});
