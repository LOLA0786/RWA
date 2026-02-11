// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol";
import "openzeppelin-contracts-upgradeable/access/OwnableUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/security/PausableUpgradeable.sol";

import "../compliance/KYCAttestationRegistry.sol";
import "../reserve/ProofOfReserveRegistry.sol";
import "../router/BridgeRouter.sol";
import "../risk/RiskEngine.sol";

contract RWALiquidityHubUpgradeable is
    Initializable,
    OwnableUpgradeable,
    PausableUpgradeable,
    UUPSUpgradeable
{
    KYCAttestationRegistry public kycRegistry;
    ProofOfReserveRegistry public reserveRegistry;
    BridgeRouter public router;
    RiskEngine public riskEngine;

    uint256 public circuitBreakerThreshold;

    event BridgeExecuted(address indexed user, address token, uint256 amount);

    function initialize(
        address _kyc,
        address _reserve,
        address _router,
        address _risk
    ) public initializer {
        __Ownable_init();
        __Pausable_init();
        __UUPSUpgradeable_init();

        kycRegistry = KYCAttestationRegistry(_kyc);
        reserveRegistry = ProofOfReserveRegistry(_reserve);
        router = BridgeRouter(_router);
        riskEngine = RiskEngine(_risk);

        circuitBreakerThreshold = 900;
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}

    function bridge(
        address token,
        uint256 amount,
        uint64 dstChain
    ) external whenNotPaused {

        require(kycRegistry.isVerified(msg.sender), "KYC required");
        require(reserveRegistry.isFullyBacked(token), "Not backed");
        require(riskEngine.getRiskScore(token) <= circuitBreakerThreshold, "Risk high");

        router.route(token, amount, dstChain);

        emit BridgeExecuted(msg.sender, token, amount);
    }
}
