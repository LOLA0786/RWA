// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./IBridgeAdapter.sol";
import "openzeppelin-contracts/access/Ownable.sol";

contract BridgeRouter is Ownable {

    mapping(bytes32 => address) public adapters;

    event AdapterRegistered(bytes32 indexed name, address adapter);
    event RouteSelected(bytes32 indexed adapterName, address token, uint256 amount);

    function registerAdapter(bytes32 name, address adapter) external onlyOwner {
        adapters[name] = adapter;
        emit AdapterRegistered(name, adapter);
    }

    function route(bytes32 adapterName, address token, uint256 amount, uint64 dstChain) external {
        address adapter = adapters[adapterName];
        require(adapter != address(0), "Adapter not found");

        emit RouteSelected(adapterName, token, amount);

        IBridgeAdapter(adapter).send(token, amount, dstChain);
    }
}
