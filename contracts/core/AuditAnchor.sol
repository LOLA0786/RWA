// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "openzeppelin-contracts/access/AccessControl.sol";

contract AuditAnchor is AccessControl {

    bytes32 public constant ANCHOR_ROLE = keccak256("ANCHOR_ROLE");

    struct Anchor {
        uint256 timestamp;
        bytes32 auditHash;
    }

    Anchor[] public anchors;

    event AuditAnchored(uint256 indexed index, bytes32 hash);

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ANCHOR_ROLE, msg.sender);
    }

    function anchorAudit(bytes32 auditHash)
        external
        onlyRole(ANCHOR_ROLE)
    {
        anchors.push(Anchor(block.timestamp, auditHash));
        emit AuditAnchored(anchors.length - 1, auditHash);
    }

    function getLatestAnchor() external view returns (Anchor memory) {
        require(anchors.length > 0, "No anchors");
        return anchors[anchors.length - 1];
    }
}
