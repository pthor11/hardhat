// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IProxy {
    function isEnableProxy(address operator, address owner)
        external
        view
        returns (bool);

    function getRuneAddress(uint256 index) external view returns (address);
}
