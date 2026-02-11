// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "openzeppelin-contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/access/AccessControl.sol";

contract InsurancePool is AccessControl {

    bytes32 public constant CLAIM_ADMIN_ROLE = keccak256("CLAIM_ADMIN_ROLE");

    IERC20 public immutable token;
    uint256 public totalDeposits;

    event Deposited(address indexed user, uint256 amount);
    event ClaimPaid(address indexed to, uint256 amount);

    constructor(address _token) {
        token = IERC20(_token);
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(CLAIM_ADMIN_ROLE, msg.sender);
    }

    function deposit(uint256 amount) external {
        token.transferFrom(msg.sender, address(this), amount);
        totalDeposits += amount;
        emit Deposited(msg.sender, amount);
    }

    function payClaim(address to, uint256 amount)
        external
        onlyRole(CLAIM_ADMIN_ROLE)
    {
        require(token.balanceOf(address(this)) >= amount, "Insufficient pool");
        token.transfer(to, amount);
        emit ClaimPaid(to, amount);
    }
}
