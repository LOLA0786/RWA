// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {RWALiquidityHub} from "../src/RWALiquidityHub.sol";
import {CCIPBridgeAdapter} from "../src/CCIPBridgeAdapter.sol";
import {SpreadOracle} from "../src/SpreadOracle.sol";
import {FeeCollector} from "../src/FeeCollector.sol";

/**
 * @notice Deploy the full RWA Liquidity Aggregator stack on a single chain.
 *
 * Usage:
 *   forge script script/Deploy.s.sol \
 *     --rpc-url $SEPOLIA_RPC_URL \
 *     --private-key $PRIVATE_KEY \
 *     --broadcast \
 *     --verify \
 *     --etherscan-api-key $ETHERSCAN_API_KEY
 */
contract Deploy is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address deployer    = vm.addr(deployerKey);

        address ccipRouter  = vm.envAddress("CCIP_ROUTER_SEPOLIA");

        console2.log("Deploying from:    ", deployer);
        console2.log("CCIP Router:       ", ccipRouter);

        vm.startBroadcast(deployerKey);

        // 1. Deploy SpreadOracle
        SpreadOracle oracle = new SpreadOracle();
        console2.log("SpreadOracle:      ", address(oracle));

        // 2. Deploy FeeCollector (needs hub address — deploy with placeholder, set later)
        //    We use a two-step pattern: deploy FeeCollector with address(1),
        //    then deploy Hub, then update FeeCollector hub address.
        //    For simplicity in v0.1, we deploy Hub first with a temp FeeCollector.
        //    Production: use CREATE2 or a factory to get deterministic addresses.
        FeeCollector feeCollector = new FeeCollector(deployer); // temp owner as hub
        console2.log("FeeCollector:      ", address(feeCollector));

        // 3. Deploy RWALiquidityHub
        RWALiquidityHub hub = new RWALiquidityHub(
            ccipRouter,
            address(oracle),
            address(feeCollector)
        );
        console2.log("RWALiquidityHub:   ", address(hub));

        // 4. Deploy CCIPBridgeAdapter (for receiving on this chain from other chains)
        CCIPBridgeAdapter adapter = new CCIPBridgeAdapter(ccipRouter);
        console2.log("CCIPBridgeAdapter: ", address(adapter));

        vm.stopBroadcast();

        // Print env vars to copy into .env
        console2.log("\n--- Copy to .env ---");
        console2.log("RWA_LIQUIDITY_HUB_SEPOLIA=", address(hub));
        console2.log("CCIP_BRIDGE_ADAPTER_SEPOLIA=", address(adapter));
        console2.log("SPREAD_ORACLE_SEPOLIA=", address(oracle));
        console2.log("FEE_COLLECTOR_SEPOLIA=", address(feeCollector));
    }
}
