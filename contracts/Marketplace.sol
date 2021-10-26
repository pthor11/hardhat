//V1
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract Marketplace is Pausable, AccessControl {
    bytes32 public constant MARKET_CONFIG = keccak256("MARKET_CONFIG");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    uint256 public minTime = 0;
    uint256 public fee = 5;
    uint256 public minNextBid = 1e6;
    address payable public owner;
    mapping(address => bool) public supportedNFT;
    struct Order {
        uint256 nftId;
        uint256 timeEnd;
        uint256 currentPrice;
        uint256 spotPrice;
        address nftContract;
        address lastBid;
        address saler;
        bool isEnd;
    }
    Order[] public orders;

    event OrderCreate(
        uint256 orderId,
        address contractNft,
        uint256 nftId,
        uint256 timeEnd,
        uint256 currentPrice,
        uint256 spotPrice
    );
    event FeeChange(uint256 newFee);
    event OrderCancel(uint256 orderId);
    event Bid(uint256 orderId, uint256 price);
    event OrderConfirmed(
        uint256 orderId,
        address buyer,
        uint256 price,
        uint256 fee
    );

    constructor() {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(MARKET_CONFIG, msg.sender);
        _setupRole(PAUSER_ROLE, msg.sender);
        owner = payable(msg.sender);
    }

    function setMinTime(uint256 _time) public onlyRole(MARKET_CONFIG) {
        minTime = _time;
    }

    function setMinNextBid(uint256 _min) public onlyRole(MARKET_CONFIG) {
        minNextBid = _min;
    }

    function setFee(uint256 _fee) public onlyRole(MARKET_CONFIG) {
        fee = _fee;
    }

    function createOrder(
        address contractNft,
        uint256 nftId,
        uint256 timeEnd,
        uint256 initPrice,
        uint256 spotPrice
    ) public whenNotPaused {
        require(supportedNFT[contractNft], "NFT must be supported");
        require(
            IERC721(contractNft).ownerOf(nftId) == msg.sender,
            "Must be owner of NFT"
        );
        require(initPrice > 0, "Price invalid");
        require(spotPrice >= initPrice || spotPrice == 0, "Spot price invalid");
        require(timeEnd >= minTime + block.timestamp, "TimeEnd is invalid");
        IERC721(contractNft).transferFrom(msg.sender, address(this), nftId);
        orders.push(
            Order(
                nftId,
                timeEnd,
                initPrice,
                spotPrice,
                contractNft,
                address(0x0),
                msg.sender,
                false
            )
        );
        emit OrderCreate(
            orders.length - 1,
            contractNft,
            nftId,
            timeEnd,
            initPrice,
            spotPrice
        );
    }

    function cancelOrder(uint256 orderId) public whenNotPaused {
        require(orderId < orders.length, "Order ID invalid");
        Order storage order = orders[orderId];
        require(order.saler == msg.sender, "Must be owner order");
        require(order.lastBid == address(0x0), "Must not have bider");
        require(!order.isEnd, "Must be not ended");
        order.isEnd = true;
        IERC721(order.nftContract).transferFrom(
            address(this),
            msg.sender,
            order.nftId
        );
        emit OrderCancel(orderId);
    }

    function bid(uint256 orderId) public payable whenNotPaused {
        require(orderId < orders.length, "Order ID invalid");
        Order storage order = orders[orderId];
        require(!order.isEnd, "Order ended");
        require(order.timeEnd > block.timestamp, "Bid time ended");
        require(
            (order.currentPrice + minNextBid <= msg.value ||
                (order.spotPrice != 0 && msg.value == order.spotPrice)),
            "Invalid bid amount"
        );
        if (order.lastBid != address(0x0))
            payable(order.lastBid).transfer(order.currentPrice);
        if (order.spotPrice != 0 && msg.value >= order.spotPrice) {
            payable(order.saler).transfer(
                (order.spotPrice * (100 - fee)) / 100
            );
            if (msg.value > order.spotPrice) {
                payable(msg.sender).transfer(order.spotPrice - msg.value);
            }
            order.lastBid = msg.sender;
            order.currentPrice = order.spotPrice;
            order.isEnd = true;
            IERC721(order.nftContract).transferFrom(
                address(this),
                msg.sender,
                order.nftId
            );
            emit OrderConfirmed(
                orderId,
                msg.sender,
                order.spotPrice,
                (order.spotPrice * fee) / 100
            );
        } else {
            order.lastBid = msg.sender;
            order.currentPrice = msg.value;
            emit Bid(orderId, msg.value);
        }
    }

    function approveSold(uint256 orderId) public whenNotPaused {
        require(orderId < orders.length, "Order ID invalid");
        Order storage order = orders[orderId];
        require(order.saler == msg.sender, "Must be owner");
        require(
            !order.isEnd && order.lastBid != address(0x0),
            "Must be can claim"
        );
        order.isEnd = true;
        IERC721(order.nftContract).transferFrom(
            address(this),
            order.lastBid,
            order.nftId
        );
        payable(order.saler).transfer((order.currentPrice * (100 - fee)) / 100);
        emit OrderConfirmed(
            orderId,
            order.lastBid,
            order.currentPrice,
            (order.currentPrice * (fee)) / 100
        );
    }

    function claim(uint256 orderId) public whenNotPaused {
        require(orderId < orders.length, "Order ID invalid");
        Order storage order = orders[orderId];
        require(
            order.timeEnd < block.timestamp &&
                !order.isEnd &&
                order.lastBid != address(0x0),
            "Must be can claim"
        );
        order.isEnd = true;
        IERC721(order.nftContract).transferFrom(
            address(this),
            order.lastBid,
            order.nftId
        );
        payable(order.saler).transfer((order.currentPrice * (100 - fee)) / 100);
        emit OrderConfirmed(
            orderId,
            order.lastBid,
            order.currentPrice,
            (order.currentPrice * (fee)) / 100
        );
    }

    function withdraw(uint256 amount) public onlyRole(DEFAULT_ADMIN_ROLE) {
        payable(owner).transfer(amount);
    }
}
