//V1
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "./IProxy.sol";

contract Runes is ERC20, ERC20Burnable, AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    IProxy public proxyOperator;

    constructor(string memory runeName, string memory runeSymbol)
        ERC20(runeName, runeSymbol)
    {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(MINTER_ROLE, msg.sender);
    }

    function addProxy(address proxy) public onlyRole(DEFAULT_ADMIN_ROLE) {
        proxyOperator = IProxy(proxy);
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public virtual override returns (bool) {
        if (
            address(proxyOperator) != address(0x0) &&
            proxyOperator.isEnableOperator(_msgSender(), sender)
        ) {
            _transfer(sender, recipient, amount);
        } else {
            super.transferFrom(sender, recipient, amount);
        }

        return true;
    }

    function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }

    function decimals() public view virtual override returns (uint8) {
        return 0;
    }
}
