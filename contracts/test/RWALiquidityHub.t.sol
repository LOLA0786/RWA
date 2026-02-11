// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {RWALiquidityHub} from "../src/RWALiquidityHub.sol";
import {CCIPBridgeAdapter} from "../src/CCIPBridgeAdapter.sol";
import {SpreadOracle} from "../src/SpreadOracle.sol";
import {FeeCollector} from "../src/FeeCollector.sol";

// ── Mock Contracts ────────────────────────────────────────────────

contract MockCCIPRouter {
    uint256 public constant MOCK_FEE = 0.01 ether;

    function getFee(uint64, bytes memory) external pure returns (uint256) {
        return MOCK_FEE;
    }

    function ccipSend(uint64, bytes memory) external payable returns (bytes32) {
        return keccak256(abi.encodePacked(block.timestamp, msg.sender));
    }
}

contract MockERC20 {
    string  public name;
    string  public symbol;
    uint8   public decimals = 18;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    constructor(string memory _name, string memory _symbol) {
        name   = _name;
        symbol = _symbol;
    }

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
        totalSupply    += amount;
        emit Transfer(address(0), to, amount);
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        require(balanceOf[msg.sender] >= amount, "ERC20: insufficient balance");
        balanceOf[msg.sender] -= amount;
        balanceOf[to]         += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        require(balanceOf[from] >= amount,         "ERC20: insufficient balance");
        require(allowance[from][msg.sender] >= amount, "ERC20: insufficient allowance");
        allowance[from][msg.sender] -= amount;
        balanceOf[from]             -= amount;
        balanceOf[to]               += amount;
        emit Transfer(from, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }
}

contract MockSpreadOracle {
    uint256 public mockSpread = 100; // 1% spread by default

    function getSpreadBps(address, uint64) external view returns (uint256) {
        return mockSpread;
    }

    function setMockSpread(uint256 bps) external { mockSpread = bps; }
}

// ── Tests ──────────────────────────────────────────────────────────

contract RWALiquidityHubTest is Test {
    RWALiquidityHub hub;
    MockCCIPRouter  ccipRouter;
    MockSpreadOracle spreadOracle;
    FeeCollector    feeCollector;
    MockERC20       rwaToken;
    MockERC20       linkToken;

    address alice  = makeAddr("alice");
    address bob    = makeAddr("bob");
    uint64  DEST_CHAIN = 12532609583862916517; // Mumbai selector

    function setUp() public {
        ccipRouter   = new MockCCIPRouter();
        spreadOracle = new MockSpreadOracle();

        // Deploy hub first (feeCollector needs hub address)
        // For testing we use a placeholder and set it after
        feeCollector = new FeeCollector(address(0)); // temp

        hub = new RWALiquidityHub(
            address(ccipRouter),
            address(spreadOracle),
            address(feeCollector)
        );

        rwaToken  = new MockERC20("Tokenized T-Bill", "tTBILL");
        linkToken = new MockERC20("Chainlink", "LINK");

        // Configure hub
        hub.addSupportedChain(DEST_CHAIN, makeAddr("destAdapter"));
        hub.addTokenRoute(address(rwaToken), DEST_CHAIN, makeAddr("destToken"));

        // Fund alice with RWA tokens
        rwaToken.mint(alice, 10_000e18);

        // Fund hub with LINK for CCIP fees
        linkToken.mint(address(hub), 10e18);
    }

    // ── Test: Bridge succeeds with sufficient spread ───────────────
    function test_bridgeAndSwap_Success() public {
        vm.startPrank(alice);
        rwaToken.approve(address(hub), 1_000e18);

        bytes32 msgId = hub.bridgeAndSwap(
            address(rwaToken),
            1_000e18,
            DEST_CHAIN,
            bob,
            0.01 ether
        );

        assertTrue(msgId != bytes32(0), "Should return a message ID");
        vm.stopPrank();
    }

    // ── Test: Protocol fee deducted correctly ─────────────────────
    function test_protocolFeeDeducted() public {
        uint256 amount = 1_000e18;
        uint256 expectedFee = (amount * hub.protocolFeeBps()) / 10_000;

        vm.startPrank(alice);
        rwaToken.approve(address(hub), amount);
        hub.bridgeAndSwap(address(rwaToken), amount, DEST_CHAIN, bob, 0.01 ether);
        vm.stopPrank();

        assertEq(
            rwaToken.balanceOf(address(feeCollector)),
            expectedFee,
            "Fee should be in collector"
        );
    }

    // ── Test: Reverts when spread too low ─────────────────────────
    function test_revertWhen_SpreadTooLow() public {
        spreadOracle.setMockSpread(10); // 0.1% < 0.5% minimum

        vm.startPrank(alice);
        rwaToken.approve(address(hub), 1_000e18);

        vm.expectRevert(
            abi.encodeWithSelector(
                RWALiquidityHub.SpreadTooLow.selector, 10, hub.minSpreadBps()
            )
        );
        hub.bridgeAndSwap(address(rwaToken), 1_000e18, DEST_CHAIN, bob, 0.01 ether);
        vm.stopPrank();
    }

    // ── Test: Reverts on unsupported chain ────────────────────────
    function test_revertWhen_UnsupportedChain() public {
        uint64 unknownChain = 999;

        vm.startPrank(alice);
        rwaToken.approve(address(hub), 100e18);

        vm.expectRevert(
            abi.encodeWithSelector(RWALiquidityHub.UnsupportedChain.selector, unknownChain)
        );
        hub.bridgeAndSwap(address(rwaToken), 100e18, unknownChain, bob, 0.01 ether);
        vm.stopPrank();
    }

    // ── Test: Reverts on zero amount ──────────────────────────────
    function test_revertWhen_ZeroAmount() public {
        vm.startPrank(alice);
        rwaToken.approve(address(hub), 0);

        vm.expectRevert(RWALiquidityHub.ZeroAmount.selector);
        hub.bridgeAndSwap(address(rwaToken), 0, DEST_CHAIN, bob, 0.01 ether);
        vm.stopPrank();
    }

    // ── Test: getBridgeQuote returns sensible values ───────────────
    function test_getBridgeQuote() public {
        (uint256 spreadBps, uint256 fee, ) = hub.getBridgeQuote(
            address(rwaToken), 1_000e18, DEST_CHAIN
        );
        assertEq(spreadBps, 100, "Spread should be mock 100 bps");
        assertEq(fee, 5e18, "Fee should be 0.5% of 1000");
    }

    // ── Test: Owner can update fee ────────────────────────────────
    function test_ownerCanSetFee() public {
        hub.setProtocolFeeBps(100); // 1%
        assertEq(hub.protocolFeeBps(), 100);
    }

    // ── Test: Non-owner cannot set fee ───────────────────────────
    function test_revertWhen_NonOwnerSetsFee() public {
        vm.prank(alice);
        vm.expectRevert();
        hub.setProtocolFeeBps(100);
    }

    // ── Fuzz: Fee never exceeds 2% ────────────────────────────────
    function testFuzz_FeeCapEnforced(uint256 newBps) public {
        vm.assume(newBps > 200);
        vm.expectRevert("Max 2% fee");
        hub.setProtocolFeeBps(newBps);
    }
}
