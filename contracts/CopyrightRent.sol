//V1
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "./IParaArt.sol";

contract ParagonDesign is Pausable, AccessControl {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    IParaArt public paraArt;
    struct SupportToken {
        bool enable;
        uint256 feePercent; // x1000
    }
    mapping(address => SupportToken) public supportsToken;
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    event EditSupportToken(address token, bool enable, uint256 feePercent);
    struct Price {
        bool enable;
        uint256 amount;
    }
    mapping(bytes32 => mapping(address => Price)) private price;

    constructor(address art) {
        paraArt = IParaArt(art);
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(PAUSER_ROLE, msg.sender);
    }

    function editSupportToken(
        address token,
        bool enable,
        uint256 feePercent
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        supportsToken[token] = SupportToken(enable, feePercent);
        emit EditSupportToken(token, enable, feePercent);
    }

    function rentByBNB(bytes32 hashed) public payable {
        SupportToken memory token = supportsToken[address(0x0)];
        require(token.enable, "Currency must be enable");
        require(paraArt.isValidHashed(hashed), "Hashed is invalid");
        Price memory p = price[hashed][address(0x0)];
        require(p.enable, "Currency not accept by owner");
        require(p.amount == msg.value, "Amount BNB is invalid");
        paraArt.copyrightRental(msg.sender, hashed);
        payable(paraArt.copyrightOwner(hashed)).transfer(
            msg.value.mul(uint256(100000).sub(token.feePercent)).div(100000)
        );
    }

    function rentByToken(bytes32 hashed, address tokenAddress) public {
        SupportToken memory token = supportsToken[tokenAddress];
        require(token.enable, "Currency must be enable");
        require(paraArt.isValidHashed(hashed), "Hashed is invalid");
        Price memory p = price[hashed][tokenAddress];
        require(p.enable, "Currency not accept by owner");
        IERC20(tokenAddress).transferFrom(msg.sender, address(this), p.amount);
        paraArt.copyrightRental(msg.sender, hashed);
        IERC20(tokenAddress).transfer(
            paraArt.copyrightOwner(hashed),
            p.amount.mul(uint256(100000).sub(token.feePercent)).div(100000)
        );
    }

    function withdraw(address token, uint256 amount)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        if (token == address(0x0)) {
            payable(msg.sender).transfer(amount);
        } else {
            IERC20(token).transfer(msg.sender, amount);
        }
    }
}
