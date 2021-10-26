//V1
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract ParagonDesign is
    ERC721,
    ERC721Enumerable,
    ERC721URIStorage,
    Pausable,
    AccessControl,
    ERC721Burnable
{
    using Counters for Counters.Counter;
    string private _URI;
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant COPYRIGHT_ROLE = keccak256("COPYRIGHT_ROLE");
    struct MetaData {
        uint256 tokenId;
        mapping(address => uint256) contracts;
    }
    mapping(uint256 => bytes32) private _idToHashed;
    mapping(bytes32 => MetaData) private _metaData;
    Counters.Counter private _tokenIdCounter;
    event CopyrightRental(address indexed renter, bytes32 hashed);
    event CopyrightUse(address indexed user, bytes32 hashed);
    event CopyrightReserved(
        address indexed owner,
        uint256 indexed tokenId,
        bytes32 hashed
    );

    constructor() ERC721("ParagonDesign", "PGD") {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(PAUSER_ROLE, msg.sender);
        _setupRole(MINTER_ROLE, msg.sender);
        _setupRole(COPYRIGHT_ROLE, msg.sender);
        _tokenIdCounter.increment();
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

    function isValidHashed(bytes32 hashed) public view returns (bool) {
        return copyrightOwner(hashed) != address(0x0);
    }

    function idToHashed(uint256 tokenId) public view returns (bytes32) {
        return _idToHashed[tokenId];
    }

    function hashedToId(bytes32 hashed) public view returns (uint256) {
        return _metaData[hashed].tokenId;
    }

    function copyrightContract(address user, bytes32 hashed)
        public
        view
        returns (uint256)
    {
        return _metaData[hashed].contracts[user];
    }

    function copyrightOwner(bytes32 hashed) public view returns (address) {
        return ownerOf(_metaData[hashed].tokenId);
    }

    function copyrightRental(address renter, bytes32 hashed)
        public
        onlyRole(COPYRIGHT_ROLE)
    {
        MetaData storage meta = _metaData[hashed];
        require(meta.tokenId > 0, "Invalid hashed");
        if (renter == ownerOf(meta.tokenId)) return;
        meta.contracts[renter]++;
        emit CopyrightRental(renter, hashed);
    }

    function copyrightUse(address user, bytes32 hashed)
        public
        onlyRole(COPYRIGHT_ROLE)
    {
        MetaData storage meta = _metaData[hashed];
        emit CopyrightUse(user, hashed);
        if (user == ownerOf(meta.tokenId)) return;
        require(meta.contracts[user] > 0, "Not allow for use");
        meta.contracts[user]--;
    }

    function safeMint(address to, bytes32 hashed) public onlyRole(MINTER_ROLE) {
        _safeMint(to, _tokenIdCounter.current());
        _idToHashed[_tokenIdCounter.current()] = hashed;
        _metaData[hashed].tokenId = _tokenIdCounter.current();
        emit CopyrightReserved(to, _tokenIdCounter.current(), hashed);
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
