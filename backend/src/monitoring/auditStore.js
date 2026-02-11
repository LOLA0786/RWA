const fs = require("fs");
const path = require("path");

const AUDIT_FILE = path.join(__dirname, "../../audit/audit-log.json");

function appendAudit(entry) {
  let logs = [];

  if (fs.existsSync(AUDIT_FILE)) {
    const raw = fs.readFileSync(AUDIT_FILE);
    logs = JSON.parse(raw);
  }

  logs.push(entry);

  fs.writeFileSync(AUDIT_FILE, JSON.stringify(logs, null, 2));
}

function getAudits() {
  if (!fs.existsSync(AUDIT_FILE)) return [];
  return JSON.parse(fs.readFileSync(AUDIT_FILE));
}

module.exports = { appendAudit, getAudits };
