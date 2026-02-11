// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "openzeppelin-contracts/access/AccessControl.sol";

contract RiskEngine is AccessControl {

    bytes32 public constant RISK_MANAGER_ROLE = keccak256("RISK_MANAGER_ROLE");

    mapping(address => uint256) public riskScores;

    event RiskUpdated(address indexed asset, uint256 score);

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(RISK_MANAGER_ROLE, msg.sender);
    }

    function updateRiskScore(address asset, uint256 score)
        external
        onlyRole(RISK_MANAGER_ROLE)
    {
        require(score <= 1000, "Invalid score");
        riskScores[asset] = score;
        emit RiskUpdated(asset, score);
    }

    function getRiskScore(address asset) external view returns (uint256) {
        return riskScores[asset];
    }
}
