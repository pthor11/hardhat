//V2
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Snapshot.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "./IPancake.sol";

contract ParallelSouls is ERC20, ERC20Snapshot, AccessControl, Pausable {
    bytes32 public constant SNAPSHOT_ROLE = keccak256("SNAPSHOT_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    address public pancakePair;
    bool public statusAntiWhale = true;
    uint256 public percentAmountWhale = 5;
    mapping(address => bool) public whaleAddress;

    constructor() ERC20("Parallel Souls", "PRL") {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(SNAPSHOT_ROLE, msg.sender);
        _setupRole(PAUSER_ROLE, msg.sender);
        _initPair();
        _mint(msg.sender, 1_000_000_000 * 10**decimals());
    }

    function _initPair() private {
        //TODO make sure pancake true
        IPancakeFactory pancakeFactory = IPancakeFactory(
            0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73
        );

        //TODO make sure busd true
        pancakePair = pancakeFactory.createPair(
            address(this),
            0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56
        );
    }

    function snapshot() public onlyRole(SNAPSHOT_ROLE) {
        _snapshot();
    }

    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function activeAntiWhale(bool _status, uint256 _percentWhale)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        statusAntiWhale = _status;
        percentAmountWhale = _percentWhale;
    }

    function markWhaleAddress(address _whale, bool _status)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        whaleAddress[_whale] = _status;
    }

    function isWhaleTransaction(
        address from,
        address to,
        uint256 amount
    ) public view returns (bool) {
        if (!statusAntiWhale) return false;
        if (to != pancakePair && from != pancakePair) return false;
        if (balanceOf(pancakePair) == 0) return false;
        if (whaleAddress[from]) return true;
        if (amount >= (balanceOf(pancakePair) * percentAmountWhale) / 100)
            return true;
        return false;
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override(ERC20, ERC20Snapshot) whenNotPaused {
        require(
            !isWhaleTransaction(from, to, amount),
            "Revert whale transaction"
        );
        super._beforeTokenTransfer(from, to, amount);
    }
}
