//V1
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./IProxy.sol";

contract RunePack is ERC721, Ownable {
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIdCounter;
    IProxy public proxy;
    event Pack(address owner, uint256 packId, bytes32 packData);
    event UnPack(address owner, uint256 packId);

    constructor(address _proxy) ERC721("RunePack", "RPP") {
        proxy = IProxy(_proxy);
    }

    function safeMint(address to) public onlyOwner {
        _safeMint(to, _tokenIdCounter.current());
        _tokenIdCounter.increment();
    }

    mapping(uint256 => bytes32) public _packData;

    function bytes32ToAmount16(bytes32 data)
        public
        pure
        returns (uint256[16] memory amount)
    {
        for (uint8 i = 0; i < 32; i++) {
            amount[i / 2] =
                amount[i / 2] +
                uint8(data[i]) *
                256**(i % 2 == 0 ? 1 : 0);
        }
    }

    function pack(bytes32 data) public {
        uint256[16] memory amount = bytes32ToAmount16(data);
        for (uint256 i = 0; i < 16; i++) {
            if (amount[i] > 0) {
                IERC20(proxy.getRuneAddress(i)).transferFrom(
                    msg.sender,
                    address(this),
                    amount[i]
                );
            }
        }
        _safeMint(msg.sender, _tokenIdCounter.current());
        _packData[_tokenIdCounter.current()] = data;
        emit Pack(msg.sender, _tokenIdCounter.current(), data);
        _tokenIdCounter.increment();
    }

    function unpack(uint256 packId) public {
        require(ownerOf(packId) == msg.sender, "Must be owner of pack");
        uint256[16] memory amount = bytes32ToAmount16(_packData[packId]);
        for (uint256 i = 0; i < 16; i++) {
            if (amount[i] > 0) {
                IERC20(proxy.getRuneAddress(i)).transfer(msg.sender, amount[i]);
            }
        }
        emit UnPack(msg.sender, packId);
        _burn(packId);
    }
}
