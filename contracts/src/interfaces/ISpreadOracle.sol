// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
interface ISpreadOracle {
    function getSpreadBps(address token, uint64 destChainSelector) external view returns (uint256);
}
