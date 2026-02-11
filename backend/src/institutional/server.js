const express = require("express");
require("dotenv").config();

const { checkCompliance } = require("../compliance/complianceEngine");
const { getReserveStatus, mint, burn } = require("../settlement/reserveEngine");
const { appendAudit, getAudits } = require("../monitoring/auditStore");

const app = express();
app.use(express.json());

function auth(req, res, next) {
  if (req.headers["x-api-key"] !== process.env.INSTITUTIONAL_API_KEY) {
    return res.status(403).json({ error: "Unauthorized" });
  }
  next();
}

app.post("/stablecoin/mint", auth, (req, res) => {
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

  const audit = {
    type: "MINT",
    address,
    amount,
    timestamp: new Date().toISOString()
  };

  appendAudit(audit);

  res.json({ status: "APPROVED", audit });
});

app.post("/stablecoin/burn", auth, (req, res) => {
  const { address, amount } = req.body;

  const compliance = checkCompliance(address);

  if (!compliance.allowed) {
    return res.json({ status: "BLOCKED", reason: compliance.reason });
  }

  burn(amount);

  const audit = {
    type: "BURN",
    address,
    amount,
    timestamp: new Date().toISOString()
  };

  appendAudit(audit);

  res.json({ status: "APPROVED", audit });
});

app.get("/stablecoin/reserve", auth, (req, res) => {
  res.json(getReserveStatus());
});

app.get("/stablecoin/audits", auth, (req, res) => {
  res.json(getAudits());
});

app.get("/health", (req, res) => {
  res.json({ status: "OK" });
});

app.listen(process.env.PORT || 3000, () => {
  console.log("Stablecoin Settlement Kernel running");
});
