const fs = require("fs");
const path = require("path");
const crypto = require("crypto");

const AUDIT_FILE = path.join(__dirname, "../../audit/audit-log.json");
const SECRET = process.env.AUDIT_SECRET || "default_secret";

function hashEntry(data) {
  return crypto.createHash("sha256").update(data).digest("hex");
}

function signHash(hash) {
  return crypto
    .createHmac("sha256", SECRET)
    .update(hash)
    .digest("hex");
}

function appendAudit(entry) {
  let logs = [];

  if (fs.existsSync(AUDIT_FILE)) {
    logs = JSON.parse(fs.readFileSync(AUDIT_FILE));
  }

  const previousHash = logs.length > 0 ? logs[logs.length - 1].hash : "GENESIS";

  const payload = JSON.stringify({
    ...entry,
    previousHash
  });

  const hash = hashEntry(payload);
  const signature = signHash(hash);

  const finalEntry = {
    ...entry,
    previousHash,
    hash,
    signature
  };

  logs.push(finalEntry);

  fs.writeFileSync(AUDIT_FILE, JSON.stringify(logs, null, 2));

  return finalEntry;
}

function getAudits() {
  if (!fs.existsSync(AUDIT_FILE)) return [];
  return JSON.parse(fs.readFileSync(AUDIT_FILE));
}

module.exports = { appendAudit, getAudits };
