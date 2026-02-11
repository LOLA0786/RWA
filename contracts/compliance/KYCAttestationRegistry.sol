// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "openzeppelin-contracts/access/Ownable.sol";

contract KYCAttestationRegistry is Ownable {
    struct Attestation {
        bool verified;
        uint256 expiresAt;
    }

    mapping(address => Attestation) public attestations;

    event KYCUpdated(address indexed user, bool verified, uint256 expiresAt);

    function updateKYC(address user, bool verified, uint256 expiresAt) external onlyOwner {
        attestations[user] = Attestation(verified, expiresAt);
        emit KYCUpdated(user, verified, expiresAt);
    }

    function isVerified(address user) public view returns (bool) {
        Attestation memory a = attestations[user];
        return a.verified && a.expiresAt > block.timestamp;
    }
}
