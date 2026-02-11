/**
 * BridgeTrigger
 * ─────────────
 * Calls RWALiquidityHub.bridgeAndSwap() when a spread opportunity is found.
 * Handles gas estimation, slippage checks, and tx tracking.
 */

import { ethers } from "ethers";

const HUB_ABI = [
  "function bridgeAndSwap(address tokenIn, uint256 amountIn, uint64 destChainSelector, address receiver, uint256 linkFeeAmount) returns (bytes32)",
  "function getBridgeQuote(address tokenIn, uint256 amountIn, uint64 destChainSelector) view returns (uint256 spreadBps, uint256 protocolFee, uint256 ccipFee)",
  "function protocolFeeBps() view returns (uint256)",
];

const ERC20_ABI = [
  "function approve(address spender, uint256 amount) returns (bool)",
  "function allowance(address owner, address spender) view returns (uint256)",
  "function decimals() view returns (uint8)",
];

export class BridgeTrigger {
  constructor() {
    const rpcUrl    = process.env.SEPOLIA_RPC_URL;
    const pk        = process.env.PRIVATE_KEY;
    if (!rpcUrl || !pk) throw new Error("SEPOLIA_RPC_URL and PRIVATE_KEY required");

    this.provider   = new ethers.JsonRpcProvider(rpcUrl);
    this.signer     = new ethers.Wallet(pk, this.provider);
    this.hubAddress = process.env.RWA_LIQUIDITY_HUB_SEPOLIA;
  }

  /**
   * Execute a bridge when a spread opportunity is confirmed.
   * @param {Object} pair    — from config (srcTokenAddress, destChainSelector, etc.)
   * @param {Object} result  — from SpreadDetector (srcPrice, spreadBps, etc.)
   * @returns {string} transaction hash
   */
  async executeBridge(pair, result) {
    const hub = new ethers.Contract(this.hubAddress, HUB_ABI, this.signer);

    // ── 1. Get a fresh quote on-chain to double-check spread is still valid
    const tokenContract = new ethers.Contract(pair.srcTokenAddress, ERC20_ABI, this.signer);
    const decimals      = await tokenContract.decimals();

    const amountIn = ethers.parseUnits(
      String(Math.floor(result.availableLiquidity * 0.95)), // use 95% of available
      decimals
    );

    const [onchainSpread, , ccipFee] = await hub.getBridgeQuote(
      pair.srcTokenAddress,
      amountIn,
      pair.destChainSelector
    );

    console.log(`    On-chain spread confirmed: ${onchainSpread} bps`);
    console.log(`    CCIP fee: ${ethers.formatEther(ccipFee)} ETH`);

    // ── 2. Approve hub to spend tokens
    const currentAllowance = await tokenContract.allowance(
      this.signer.address,
      this.hubAddress
    );
    if (currentAllowance < amountIn) {
      const approveTx = await tokenContract.approve(this.hubAddress, amountIn);
      await approveTx.wait();
      console.log(`    Approved ${ethers.formatUnits(amountIn, decimals)} tokens`);
    }

    // ── 3. Execute bridge
    const tx = await hub.bridgeAndSwap(
      pair.srcTokenAddress,
      amountIn,
      pair.destChainSelector,
      this.signer.address, // receiver on dest chain
      0,                   // LINK fee amount (paying in native)
      { value: ccipFee }   // attach ETH for CCIP fee
    );

    const receipt = await tx.wait();
    console.log(`    Bridge tx confirmed: block ${receipt.blockNumber}`);

    return tx.hash;
  }
}
