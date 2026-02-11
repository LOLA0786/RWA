const { ethers } = require("ethers");
const { getAudits } = require("./auditStore");

const RPC_URL = process.env.RPC_URL;
const PRIVATE_KEY = process.env.PRIVATE_KEY;
const CONTRACT_ADDRESS = process.env.AUDIT_ANCHOR_ADDRESS;

const ABI = [
  "function anchorAudit(bytes32 auditHash) external"
];

async function anchorLatestAudit() {
  try {
    const audits = getAudits();
    if (!audits.length) return;

    const latestHash = audits[audits.length - 1].hash;

    const provider = new ethers.JsonRpcProvider(RPC_URL);
    const wallet = new ethers.Wallet(PRIVATE_KEY, provider);
    const contract = new ethers.Contract(CONTRACT_ADDRESS, ABI, wallet);

    const tx = await contract.anchorAudit(latestHash);
    console.log("🔗 Anchor tx sent:", tx.hash);

    await tx.wait();
    console.log("✅ Anchor confirmed on-chain");

  } catch (err) {
    console.error("❌ Anchor failed:", err.message);
  }
}

module.exports = { anchorLatestAudit };
