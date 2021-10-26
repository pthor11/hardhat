// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IParaArt {
    function isValidHashed(bytes32 hashed) external view returns (bool);

    function copyrightOwner(bytes32 hashed) external view returns (address);

    function copyrightRental(address renter, bytes32 hashed) external;

    function copyrightUse(address user, bytes32 hashed) external;

    function idToHashed(uint256 tokenId) external view returns (bytes32);

    function hashedToId(bytes32 hashed) external view returns (uint256);

    function copyrightContract(address user, bytes32 hashed)
        external
        view
        returns (uint256);
}
