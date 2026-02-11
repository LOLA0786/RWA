// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "openzeppelin-contracts/access/Ownable.sol";

contract SettlementFeeEngine is Ownable {

    uint256 public feeBps; // basis points (e.g. 10 = 0.10%)

    event FeeUpdated(uint256 newFeeBps);

    constructor(uint256 _feeBps) {
        feeBps = _feeBps;
    }

    function setFee(uint256 _feeBps) external onlyOwner {
        require(_feeBps <= 1000, "Fee too high");
        feeBps = _feeBps;
        emit FeeUpdated(_feeBps);
    }

    function calculateFee(uint256 amount) public view returns (uint256) {
        return (amount * feeBps) / 10000;
    }
}
