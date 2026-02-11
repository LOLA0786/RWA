const express = require("express");
require("dotenv").config();

const app = express();
app.use(express.json());

function auth(req, res, next) {
  if (req.headers["x-api-key"] !== process.env.INSTITUTIONAL_API_KEY) {
    return res.status(403).json({ error: "Unauthorized" });
  }
  next();
}

app.post("/stablecoin/mint", auth, (req, res) => {
  return res.json({
    status: "APPROVED",
    action: "MINT",
    audit_id: Date.now().toString(),
  });
});

app.post("/stablecoin/burn", auth, (req, res) => {
  return res.json({
    status: "APPROVED",
    action: "BURN",
    audit_id: Date.now().toString(),
  });
});

app.get("/health", (req, res) => {
  res.json({ status: "OK" });
});

app.listen(process.env.PORT || 3000, () => {
  console.log("Stablecoin Settlement Kernel running");
});
