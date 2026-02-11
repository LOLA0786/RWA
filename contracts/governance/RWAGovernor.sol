// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "openzeppelin-contracts/governance/Governor.sol";
import "openzeppelin-contracts/governance/extensions/GovernorVotes.sol";
import "openzeppelin-contracts/governance/extensions/GovernorCountingSimple.sol";
import "openzeppelin-contracts/governance/extensions/GovernorTimelockControl.sol";
import "openzeppelin-contracts/governance/TimelockController.sol";

contract RWAGovernor is
    Governor,
    GovernorVotes,
    GovernorCountingSimple,
    GovernorTimelockControl
{
    constructor(IVotes _token, TimelockController _timelock)
        Governor("RWAGovernor")
        GovernorVotes(_token)
        GovernorTimelockControl(_timelock)
    {}

    function votingDelay() public pure override returns (uint256) {
        return 1;
    }

    function votingPeriod() public pure override returns (uint256) {
        return 45818; // ~1 week
    }

    function quorum(uint256) public pure override returns (uint256) {
        return 1_000_000 ether;
    }

    function proposalThreshold() public pure override returns (uint256) {
        return 100_000 ether;
    }

    function _execute(
        uint256 proposalId,
        address target,
        uint256 value,
        bytes calldata data,
        bytes32 predecessor,
        bytes32 salt
    ) internal override(Governor, GovernorTimelockControl) {
        super._execute(proposalId, target, value, data, predecessor, salt);
    }

    function _cancel(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(Governor, GovernorTimelockControl) returns (uint256) {
        return super._cancel(targets, values, calldatas, descriptionHash);
    }

    function state(uint256 proposalId)
        public
        view
        override(Governor, GovernorTimelockControl)
        returns (ProposalState)
    {
        return super.state(proposalId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(Governor, GovernorTimelockControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
