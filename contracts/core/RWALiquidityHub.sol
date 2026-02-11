// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../compliance/KYCAttestationRegistry.sol";
import "../reserve/ProofOfReserveRegistry.sol";
import "../router/BridgeRouter.sol";
import "../risk/RiskEngine.sol";
import "openzeppelin-contracts/access/Ownable.sol";
import "openzeppelin-contracts/security/Pausable.sol";

contract RWALiquidityHub is Ownable, Pausable {

    KYCAttestationRegistry public kycRegistry;
    ProofOfReserveRegistry public reserveRegistry;
    BridgeRouter public router;
    RiskEngine public riskEngine;

    uint256 public circuitBreakerThreshold = 900; // max risk score allowed

    event BridgeExecuted(address indexed user, address token, uint256 amount);

    constructor(
        address _kyc,
        address _reserve,
        address _router,
        address _risk
    ) {
        kycRegistry = KYCAttestationRegistry(_kyc);
        reserveRegistry = ProofOfReserveRegistry(_reserve);
        router = BridgeRouter(_router);
        riskEngine = RiskEngine(_risk);
    }

    function setCircuitBreaker(uint256 threshold) external onlyOwner {
        circuitBreakerThreshold = threshold;
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function bridge(
        address token,
        uint256 amount,
        uint64 dstChain
    ) external whenNotPaused {

        require(kycRegistry.isVerified(msg.sender), "KYC required");
        require(reserveRegistry.isFullyBacked(token), "Not fully backed");

        uint256 riskScore = riskEngine.getRiskScore(token);
        require(riskScore <= circuitBreakerThreshold, "Risk too high");

        router.route(token, amount, dstChain);

        emit BridgeExecuted(msg.sender, token, amount);
    }
}
