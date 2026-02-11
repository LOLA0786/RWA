const { ethers } = require("ethers");
const keccak256 = require("keccak256");
const { MerkleTree } = require("merkletreejs");
const { query } = require("../db/postgres");

const RPC_URL = process.env.RPC_URL;
const PRIVATE_KEY = process.env.PRIVATE_KEY;
const CONTRACT_ADDRESS = process.env.AUDIT_ANCHOR_ADDRESS;

const ABI = ["function anchorAudit(bytes32 root) external"];

async function anchorMerkleBatch() {
  const result = await query(
    "SELECT hash FROM audit_logs ORDER BY id DESC LIMIT 50"
  );

  if (!result.rows.length) return;

  const leaves = result.rows.map(r => keccak256(r.hash));
  const tree = new MerkleTree(leaves, keccak256, { sortPairs: true });

  const root = tree.getHexRoot();

  const provider = new ethers.JsonRpcProvider(RPC_URL);
  const wallet = new ethers.Wallet(PRIVATE_KEY, provider);
  const contract = new ethers.Contract(CONTRACT_ADDRESS, ABI, wallet);

  const tx = await contract.anchorAudit(root);
  console.log("🌳 Merkle root anchored:", tx.hash);

  await tx.wait();
}

module.exports = { anchorMerkleBatch };
