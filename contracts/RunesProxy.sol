//V1
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;
import "@openzeppelin/contracts/access/Ownable.sol";

contract Operator is Ownable {
    mapping(address => bool) private _isOperator;
    mapping(address => bool) private _isBlockOperator;
    mapping(uint256 => address) private _runeAddress;

    event NewOperator(address operator);
    event RevokeOperator(address operator);
    event BlockOperator(address owner);
    event UnBlockOperator(address owner);
    event RuneAddressSet(uint256 index, address runeAddress);

    function getRuneAddress(uint256 index) public view returns (address) {
        return _runeAddress[index];
    }

    function configRuneAddress(uint256 index, address rune) public onlyOwner {
        _runeAddress[index] = rune;
        emit RuneAddressSet(index, rune);
    }

    function isOperator(address operator) public view returns (bool) {
        return _isOperator[operator];
    }

    function isEnableOperator(address operator, address owner)
        public
        view
        returns (bool)
    {
        return _isOperator[operator] && !_isBlockOperator[owner];
    }

    function setOperator(address operator) public onlyOwner {
        if (!_isOperator[operator]) {
            _isOperator[operator] = true;
            emit NewOperator(operator);
        }
    }

    function revokeOperator(address operator) public onlyOwner {
        if (_isOperator[operator]) {
            _isOperator[operator] = false;
            emit RevokeOperator(operator);
        }
    }

    function blockOperator() public {
        if (!_isBlockOperator[msg.sender]) {
            _isBlockOperator[msg.sender] = true;
            emit BlockOperator(msg.sender);
        }
    }

    function unblockOperator() public {
        if (_isBlockOperator[msg.sender]) {
            _isBlockOperator[msg.sender] = false;
            emit UnBlockOperator(msg.sender);
        }
    }
}
