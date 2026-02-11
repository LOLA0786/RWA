const crypto = require("crypto");
const { query } = require("../db/postgres");

const SECRET = process.env.AUDIT_SECRET || "default_secret";

function sha256(data) {
  return crypto.createHash("sha256").update(data).digest("hex");
}

function sign(hash) {
  return crypto.createHmac("sha256", SECRET).update(hash).digest("hex");
}

async function appendAudit(entry) {
  const prev = await query(
    "SELECT hash FROM audit_logs ORDER BY id DESC LIMIT 1"
  );

  const previousHash = prev.rows[0]?.hash || "GENESIS";

  const payload = JSON.stringify({ ...entry, previousHash });
  const hash = sha256(payload);
  const signature = sign(hash);

  const result = await query(
    `INSERT INTO audit_logs(type, address, amount, region, previous_hash, hash, signature)
     VALUES($1,$2,$3,$4,$5,$6,$7)
     RETURNING *`,
    [
      entry.type,
      entry.address,
      entry.amount,
      process.env.REGION || "unknown",
      previousHash,
      hash,
      signature
    ]
  );

  return result.rows[0];
}

async function getAudits() {
  const result = await query("SELECT * FROM audit_logs ORDER BY id DESC LIMIT 100");
  return result.rows;
}

module.exports = { appendAudit, getAudits };
