// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {CCIPReceiver} from "@chainlink/contracts-ccip/src/v0.8/ccip/applications/CCIPReceiver.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title CCIPBridgeAdapter
 * @notice Deployed on DESTINATION chains. Receives CCIP messages from
 *         RWALiquidityHub on source chain, validates them, and releases
 *         the equivalent RWA tokens to the intended receiver.
 *
 * @dev Security model:
 *      - Only accepts messages from whitelisted source chains
 *      - Only accepts messages from the registered RWALiquidityHub on each chain
 *      - Emits ArbitrageCompleted for off-chain monitoring
 */
contract CCIPBridgeAdapter is CCIPReceiver, Ownable {
    using SafeERC20 for IERC20;

    // ── State ─────────────────────────────────────────────────────

    /// @dev srcChainSelector => allowed sender (RWALiquidityHub address)
    mapping(uint64 => address) public allowedSenders;

    /// @dev srcChainSelector => allowed flag
    mapping(uint64 => bool) public allowedSourceChains;

    /// @dev Mapping of supported local tokens
    mapping(address => bool) public supportedTokens;

    // ── Events ────────────────────────────────────────────────────
    event ArbitrageCompleted(
        bytes32 indexed ccipMessageId,
        address indexed receiver,
        address token,
        uint256 amount,
        uint64  srcChainSelector
    );
    event SourceChainAdded(uint64 chainSelector, address sender);
    event TokenSupported(address token);

    // ── Errors ────────────────────────────────────────────────────
    error SourceChainNotAllowed(uint64 chainSelector);
    error SenderNotAllowed(address sender);
    error TokenNotSupported(address token);
    error InsufficientVaultBalance(address token, uint256 requested, uint256 available);

    // ── Constructor ───────────────────────────────────────────────
    constructor(address _ccipRouter) CCIPReceiver(_ccipRouter) Ownable(msg.sender) {}

    // ── CCIP Receive ──────────────────────────────────────────────

    /**
     * @dev Called by Chainlink CCIP router when a message arrives.
     *      Validates source, decodes payload, releases tokens to receiver.
     */
    function _ccipReceive(Client.Any2EVMMessage memory message)
        internal
        override
    {
        uint64  srcChain = message.sourceChainSelector;
        address sender   = abi.decode(message.sender, (address));

        // ── Security checks
        if (!allowedSourceChains[srcChain]) revert SourceChainNotAllowed(srcChain);
        if (allowedSenders[srcChain] != sender) revert SenderNotAllowed(sender);

        // ── Decode payload: (destToken, amount, receiver)
        (address token, uint256 amount, address receiver) = abi.decode(
            message.data,
            (address, uint256, address)
        );

        if (!supportedTokens[token]) revert TokenNotSupported(token);

        uint256 vaultBalance = IERC20(token).balanceOf(address(this));
        if (vaultBalance < amount) {
            revert InsufficientVaultBalance(token, amount, vaultBalance);
        }

        // ── Release tokens to receiver
        IERC20(token).safeTransfer(receiver, amount);

        emit ArbitrageCompleted(
            message.messageId,
            receiver,
            token,
            amount,
            srcChain
        );
    }

    // ── Admin ─────────────────────────────────────────────────────

    function addAllowedSourceChain(
        uint64  chainSelector,
        address hubAddress
    ) external onlyOwner {
        allowedSourceChains[chainSelector] = true;
        allowedSenders[chainSelector]      = hubAddress;
        emit SourceChainAdded(chainSelector, hubAddress);
    }

    function addSupportedToken(address token) external onlyOwner {
        supportedTokens[token] = true;
        emit TokenSupported(token);
    }

    /// @notice Fund the vault with RWA tokens to fulfil incoming bridges
    function fundVault(address token, uint256 amount) external {
        require(supportedTokens[token], "Token not supported");
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
    }

    function vaultBalance(address token) external view returns (uint256) {
        return IERC20(token).balanceOf(address(this));
    }
}
