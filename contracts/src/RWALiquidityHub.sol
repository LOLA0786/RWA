// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IRouterClient} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {ISpreadOracle} from "./interfaces/ISpreadOracle.sol";
import {FeeCollector} from "./FeeCollector.sol";

/**
 * @title RWALiquidityHub
 * @notice Main entry point for cross-chain RWA liquidity aggregation.
 *         Users call bridgeAndSwap() to move RWA tokens across chains
 *         when a profitable spread exists. Protocol takes a fee.
 *
 * @dev Uses Chainlink CCIP for cross-chain messaging.
 *      Spread oracle reads Chainlink Data Feeds on both source and destination.
 */
contract RWALiquidityHub is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ── State ─────────────────────────────────────────────────────
    IRouterClient public immutable ccipRouter;
    ISpreadOracle  public immutable spreadOracle;
    FeeCollector   public immutable feeCollector;

    /// @dev fee in basis points (50 = 0.5%)
    uint256 public protocolFeeBps = 50;

    /// @dev minimum spread in bps to allow a bridge (prevents spam)
    uint256 public minSpreadBps = 50;

    /// @dev supported destination chain selectors
    mapping(uint64 => bool) public supportedChains;

    /// @dev registered RWA tokens: localToken => destChainSelector => destToken
    mapping(address => mapping(uint64 => address)) public tokenRoutes;

    /// @dev CCIP adapter address on each destination chain
    mapping(uint64 => address) public destAdapters;

    // ── Events ────────────────────────────────────────────────────
    event BridgeInitiated(
        bytes32 indexed ccipMessageId,
        address indexed user,
        address tokenIn,
        uint256 amountIn,
        uint256 amountAfterFee,
        uint64  destChainSelector
    );
    event ChainAdded(uint64 chainSelector, address adapter);
    event TokenRouteAdded(address srcToken, uint64 destChain, address destToken);
    event FeeBpsUpdated(uint256 oldBps, uint256 newBps);

    // ── Errors ────────────────────────────────────────────────────
    error UnsupportedChain(uint64 chainSelector);
    error UnsupportedToken(address token, uint64 destChain);
    error SpreadTooLow(uint256 spreadBps, uint256 minSpreadBps);
    error InsufficientLinkBalance(uint256 have, uint256 need);
    error ZeroAmount();

    // ── Constructor ───────────────────────────────────────────────
    constructor(
        address _ccipRouter,
        address _spreadOracle,
        address _feeCollector
    ) Ownable(msg.sender) {
        ccipRouter    = IRouterClient(_ccipRouter);
        spreadOracle  = ISpreadOracle(_spreadOracle);
        feeCollector  = FeeCollector(_feeCollector);
    }

    // ── Core: Bridge & Swap ───────────────────────────────────────

    /**
     * @notice Bridge RWA tokens to another chain where price is higher.
     * @param tokenIn           Local RWA token address
     * @param amountIn          Amount to bridge (in token decimals)
     * @param destChainSelector Chainlink CCIP chain selector for destination
     * @param receiver          Address to receive tokens on destination chain
     * @param linkFeeAmount     Amount of LINK to pay for CCIP fees
     */
    function bridgeAndSwap(
        address tokenIn,
        uint256 amountIn,
        uint64  destChainSelector,
        address receiver,
        uint256 linkFeeAmount
    ) external nonReentrant returns (bytes32 messageId) {
        if (amountIn == 0) revert ZeroAmount();
        if (!supportedChains[destChainSelector]) revert UnsupportedChain(destChainSelector);

        address destToken = tokenRoutes[tokenIn][destChainSelector];
        if (destToken == address(0)) revert UnsupportedToken(tokenIn, destChainSelector);

        // ── 1. Validate spread is large enough to be worth bridging
        uint256 spreadBps = spreadOracle.getSpreadBps(tokenIn, destChainSelector);
        if (spreadBps < minSpreadBps) revert SpreadTooLow(spreadBps, minSpreadBps);

        // ── 2. Pull tokens from user
        IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);

        // ── 3. Deduct protocol fee
        uint256 feeAmount = (amountIn * protocolFeeBps) / 10_000;
        uint256 amountAfterFee = amountIn - feeAmount;

        // Send fee to collector
        IERC20(tokenIn).safeTransfer(address(feeCollector), feeAmount);
        feeCollector.recordFee(tokenIn, feeAmount);

        // ── 4. Build CCIP message
        Client.EVM2AnyMessage memory ccipMsg = _buildCCIPMessage(
            receiver,
            destToken,
            amountAfterFee,
            tokenIn,
            linkFeeAmount
        );

        // ── 5. Validate LINK fee coverage
        uint256 ccipFee = ccipRouter.getFee(destChainSelector, ccipMsg);
        if (IERC20(_getLinkToken()).balanceOf(address(this)) < ccipFee) {
            revert InsufficientLinkBalance(
                IERC20(_getLinkToken()).balanceOf(address(this)),
                ccipFee
            );
        }

        // ── 6. Approve token transfer to CCIP router
        IERC20(tokenIn).approve(address(ccipRouter), amountAfterFee);

        // ── 7. Send via CCIP
        messageId = ccipRouter.ccipSend(destChainSelector, ccipMsg);

        emit BridgeInitiated(
            messageId,
            msg.sender,
            tokenIn,
            amountIn,
            amountAfterFee,
            destChainSelector
        );
    }

    // ── Fee Quote (read-only) ─────────────────────────────────────

    /**
     * @notice Get a quote for bridging without executing.
     * @return spreadBps        Current spread in bps between src/dest
     * @return protocolFee      Protocol fee in token units
     * @return ccipFee          LINK required for CCIP message
     */
    function getBridgeQuote(
        address tokenIn,
        uint256 amountIn,
        uint64  destChainSelector
    ) external view returns (
        uint256 spreadBps,
        uint256 protocolFee,
        uint256 ccipFee
    ) {
        spreadBps   = spreadOracle.getSpreadBps(tokenIn, destChainSelector);
        protocolFee = (amountIn * protocolFeeBps) / 10_000;

        Client.EVM2AnyMessage memory ccipMsg = _buildCCIPMessage(
            address(0), // placeholder receiver
            tokenRoutes[tokenIn][destChainSelector],
            amountIn - protocolFee,
            tokenIn,
            0
        );
        ccipFee = ccipRouter.getFee(destChainSelector, ccipMsg);
    }

    // ── Admin ─────────────────────────────────────────────────────

    function addSupportedChain(uint64 chainSelector, address adapter) external onlyOwner {
        supportedChains[chainSelector] = true;
        destAdapters[chainSelector]    = adapter;
        emit ChainAdded(chainSelector, adapter);
    }

    function addTokenRoute(
        address srcToken,
        uint64  destChain,
        address destToken
    ) external onlyOwner {
        tokenRoutes[srcToken][destChain] = destToken;
        emit TokenRouteAdded(srcToken, destChain, destToken);
    }

    function setProtocolFeeBps(uint256 newBps) external onlyOwner {
        require(newBps <= 200, "Max 2% fee");
        emit FeeBpsUpdated(protocolFeeBps, newBps);
        protocolFeeBps = newBps;
    }

    function setMinSpreadBps(uint256 newBps) external onlyOwner {
        minSpreadBps = newBps;
    }

    /// @notice Withdraw LINK from contract to cover CCIP fees
    function withdrawLink(address to, uint256 amount) external onlyOwner {
        IERC20(_getLinkToken()).safeTransfer(to, amount);
    }

    // ── Internal ──────────────────────────────────────────────────

    function _buildCCIPMessage(
        address receiver,
        address destToken,
        uint256 amount,
        address srcToken,
        uint256 /* linkFeeHint */
    ) internal pure returns (Client.EVM2AnyMessage memory) {
        Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](1);
        tokenAmounts[0] = Client.EVMTokenAmount({
            token:  srcToken,
            amount: amount
        });

        return Client.EVM2AnyMessage({
            receiver:         abi.encode(receiver),
            data:             abi.encode(destToken, amount),
            tokenAmounts:     tokenAmounts,
            extraArgs:        Client._argsToBytes(
                                  Client.EVMExtraArgsV1({gasLimit: 200_000})
                              ),
            feeToken:         address(0) // pay in native (override if using LINK)
        });
    }

    /// @dev Override in tests or subclass to inject different LINK address
    function _getLinkToken() internal view virtual returns (address) {
        // Sepolia LINK — replace with network-specific address via constructor arg in production
        return 0x779877A7B0D9E8603169DdbD7836e478b4624789;
    }
}
