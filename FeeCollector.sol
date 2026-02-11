// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title FeeCollector
 * @notice Accumulates protocol fees from RWALiquidityHub.
 *         Owner can claim fees anytime.
 *         Emits events for off-chain revenue tracking.
 */
contract FeeCollector is Ownable {
    using SafeERC20 for IERC20;

    mapping(address => uint256) public totalFeesCollected;
    mapping(address => uint256) public unclaimedFees;

    address public immutable hub; // only hub can record fees

    event FeeRecorded(address indexed token, uint256 amount, uint256 totalToDate);
    event FeeClaimed(address indexed token, uint256 amount, address to);

    error OnlyHub();
    error NothingToClaim();

    constructor(address _hub) Ownable(msg.sender) {
        hub = _hub;
    }

    function recordFee(address token, uint256 amount) external {
        if (msg.sender != hub) revert OnlyHub();
        totalFeesCollected[token] += amount;
        unclaimedFees[token]      += amount;
        emit FeeRecorded(token, amount, totalFeesCollected[token]);
    }

    function claimFees(address token, address to) external onlyOwner {
        uint256 amount = unclaimedFees[token];
        if (amount == 0) revert NothingToClaim();
        unclaimedFees[token] = 0;
        IERC20(token).safeTransfer(to, amount);
        emit FeeClaimed(token, amount, to);
    }
}
