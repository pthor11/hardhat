//V2
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./IParaArt.sol";
import "./IProxy.sol";

contract Paragon is
    ERC721,
    ERC721Enumerable,
    ERC721URIStorage,
    Pausable,
    AccessControl,
    ERC721Burnable
{
    using Counters for Counters.Counter;
    IParaArt public artContract;
    IProxy public proxy;
    struct ParagonStruct {
        bytes32 originalArt;
        bytes32 rawHashed;
        bytes32 runesList;
    }

    mapping(uint256 => ParagonStruct) public paragonDNA;
    string private _URI;
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant HYDRA_ROLE = keccak256("HYDRA_ROLE");

    Counters.Counter private _tokenIdCounter;

    constructor(address art,address _proxy) ERC721("Paragon", "PG") {
        artContract = IParaArt(art);
        proxy = IProxy(_proxy);
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(PAUSER_ROLE, msg.sender);
        _setupRole(MINTER_ROLE, msg.sender);
    }

    function bytes32ToAmount16(bytes32 data)
        public
        pure
        returns (uint256[16] memory amount)
    {
        for(uint8 i=0;i<32;i++){
            amount[i/2] = amount[i/2] + uint8(data[i]) * 256 ** (i%2 == 0 ? 1: 0); 
        }
    }

    function _baseURI() internal view override returns (string memory) {
        return _URI;
    }

    function changeBaseURI(string memory _newURI)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        _URI = _newURI;
    }

    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function safeMint(
        address to,
        bytes32 originalArt,
        bytes32 rawHashed,
        bytes32 runesList
    ) public onlyRole(MINTER_ROLE) {
        _safeMint(to, _tokenIdCounter.current());
        paragonDNA[_tokenIdCounter.current()] = ParagonStruct(
            originalArt,
            rawHashed,
            runesList
        );
        artContract.copyrightUse(to, originalArt);
        uint256[16] memory amount = bytes32ToAmount16(runesList);
        for (uint256 i = 0; i < 16; i++) {
            if (amount[i] > 0) {
                IERC20(proxy.getRuneAddress(i)).transferFrom(
                    msg.sender,
                    address(this),
                    amount[i]
                );
            }
        }
        _tokenIdCounter.increment();
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override(ERC721, ERC721Enumerable) whenNotPaused {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    // The following functions are overrides required by Solidity.

    function _burn(uint256 tokenId)
        internal
        override(ERC721, ERC721URIStorage)
    {
        artContract.copyrightRental(
            ownerOf(tokenId),
            paragonDNA[tokenId].originalArt
        );
        //TODO burn percent
        uint256[16] memory amount = bytes32ToAmount16(paragonDNA[tokenId].runesList);
        for (uint256 i = 0; i < 16; i++) {
            if (amount[i] > 0) {
                IERC20(proxy.getRuneAddress(i)).transfer(msg.sender, amount[i]);
            }
        }
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
