// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "openzeppelin-contracts/token/ERC20/extensions/ERC20Votes.sol";
import "openzeppelin-contracts/access/Ownable.sol";

contract RWAToken is ERC20Votes, Ownable {

    constructor()
        ERC20("RWA Governance Token", "RWA")
        ERC20Permit("RWA Governance Token")
    {
        _mint(msg.sender, 100_000_000 ether);
    }

    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }
}
