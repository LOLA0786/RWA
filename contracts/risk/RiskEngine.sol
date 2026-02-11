// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "openzeppelin-contracts/access/Ownable.sol";

contract RiskEngine is Ownable {

    mapping(address => uint256) public riskScores;

    event RiskUpdated(address indexed asset, uint256 score);

    function updateRiskScore(address asset, uint256 score) external onlyOwner {
        require(score <= 1000, "Invalid score");
        riskScores[asset] = score;
        emit RiskUpdated(asset, score);
    }

    function getRiskScore(address asset) external view returns (uint256) {
        return riskScores[asset];
    }
}
