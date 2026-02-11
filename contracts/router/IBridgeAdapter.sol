// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IBridgeAdapter {
    function send(address token, uint256 amount, uint64 dstChain) external;
}
