//V3
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./IPancake.sol";

contract TokenDistribution is AccessControl {
    using SafeMath for uint256;
    bytes32 public constant ADDLIQUIDITY_ROLE = keccak256("ADDLIQUIDITY_ROLE");
    IPancakeRouter02 public pancakeRouter;
    address public busd;
    uint256 public capped;
    uint256 public allotted;
    uint256 public timeRelease = 0;
    uint256 public timePeriod = 30 days;
    uint256 public constant DAY = 1 days;
    IERC20 public token;
    struct Investor {
        uint256 total;
        uint256 claimed;
        uint256 packageId;
    }
    mapping(address => Investor) public investors;
    mapping(address => mapping(address => bool)) public approved;
    struct Package {
        uint256 unlockPercent;
        uint256 lockedTime;
        uint256 vestingTime;
    }
    Package[] public packages;
    event NewPackage(
        uint256 packageId,
        uint256 unlockPercent,
        uint256 lockedTime,
        uint256 vestingTime
    );
    event NewInvestor(address investor, uint256 packageId, uint256 amount);
    event MoreAllocation(address investor, uint256 amount);

    constructor(
        address _token,
        address _busd,
        address _pancakeRouter,
        uint256 _timePeriod
    ) {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(ADDLIQUIDITY_ROLE, msg.sender);
        capped = 1_000_000_000 * (10**18);
        token = IERC20(_token);
        busd = _busd;
        _setupInitPackage();
        pancakeRouter = IPancakeRouter02(_pancakeRouter);
        timePeriod = _timePeriod;
    }

    function allocation(
        address investor,
        uint256 packageId,
        uint256 amount
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        require(packageId < packages.length, "PackageId not valid");
        require(allotted.add(amount) <= capped, "Full out");
        require(
            investors[investor].packageId == 0 && packageId > 0,
            "Must be fresh"
        );
        investors[investor] = Investor(amount, 0, packageId);
        allotted = allotted.add(amount);
        emit NewInvestor(investor, packageId, amount);
    }

    function addMoreAllocation(address investor, uint256 amount)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(allotted.add(amount) <= capped, "Full out");
        require(investors[investor].packageId != 0, "Investor not found");
        investors[investor].total = investors[investor].total.add(amount);
        allotted = allotted.add(amount);
        emit MoreAllocation(investor, amount);
    }

    function getClaimAmount(address user) public view returns (uint256) {
        if (block.timestamp < timeRelease) return 0;
        Investor memory investor = investors[user];
        if (investor.packageId == 0) return 0;
        Package memory pack = packages[investor.packageId - 1];
        uint256 claimable = investor.total.mul(pack.unlockPercent).div(100);
        if (block.timestamp.sub(timeRelease) > pack.lockedTime) {
            uint256 unlockAmount = investor
                .total
                .sub(claimable)
                .mul(
                    (block.timestamp.sub(timeRelease).sub(pack.lockedTime)).div(
                        timePeriod
                    )
                )
                .div((pack.vestingTime).div(timePeriod));
            claimable = claimable.add(unlockAmount);
        }
        if (claimable > investor.total) {
            claimable = investor.total;
        }
        return claimable - investor.claimed;
    }

    function approve(address operator, bool status) public {
        approved[msg.sender][operator] = status;
    }

    function allocationFor(address user, uint256 amount) public {
        Investor storage investor = investors[msg.sender];
        require(investor.total >= amount, "Must be have");
        uint256 claimed = (investor.claimed * amount) / investor.total;
        investor.claimed = investor.claimed.sub(claimed);
        investor.total = investor.total.sub(amount);
        require(investors[user].packageId == 0, "Must be fresh");
        investors[user] = Investor(amount, claimed, investor.packageId);
        if (claimed > 0) {
            token.transferFrom(msg.sender, user, claimed);
        }
    }

    function claim() public {
        uint256 amount = getClaimAmount(msg.sender);
        require(amount > 0, "Must be > 0");
        investors[msg.sender].claimed = investors[msg.sender].claimed.add(
            amount
        );
        token.transfer(msg.sender, amount);
    }

    function useFund(address fund, uint256 amount) public {
        require(approved[fund][msg.sender], "Must be approved");
        uint256 amountAvailable = getClaimAmount(fund);
        require(amountAvailable >= amount, "Must be available for use");
        require(amount > 0, "Must be > 0");
        investors[fund].claimed = investors[fund].claimed.add(amount);
        token.transfer(msg.sender, amount);
    }

    function _setupInitPackage() private {
        // Dumpy
        addPackage(0, 30000 * DAY, 30000 * DAY);
        // Advisors
        addPackage(0, 90 * DAY, 300 * DAY);
        // Seed Round
        addPackage(10, 60 * DAY, 270 * DAY);
        // Private Round
        addPackage(20, 60 * DAY, 240 * DAY);
        // Public Round
        addPackage(25, 30 * DAY, 90 * DAY);
        // Team
        addPackage(0, 0 * DAY, 750 * DAY);
        // Ecosystem + Marketing
        addPackage(0, 0 * DAY, 1500 * DAY);
        // Game rewards
        addPackage(0, 0 * DAY, 1500 * DAY);
    }

    function addPackage(
        uint256 unlockPercent,
        uint256 lockedTime,
        uint256 vestingTime
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        packages.push(Package(unlockPercent, lockedTime, vestingTime));
        emit NewPackage(
            packages.length - 1,
            unlockPercent,
            lockedTime,
            vestingTime
        );
    }

    function setupLiquidity() public onlyRole(DEFAULT_ADMIN_ROLE) {
        require(
            capped.sub(allotted) > 2_000_000 * 1e18,
            "Must be have liquidity"
        );
        require(timeRelease == 0, "Must be fresh liquidity");
        token.approve(address(pancakeRouter), 1e40);
        IERC20(busd).approve(address(pancakeRouter), 1e40);
        pancakeRouter.addLiquidity(
            address(token),
            busd,
            2_000_000 * 1e18,
            200_000 * 1e18,
            0,
            0,
            address(this),
            block.timestamp
        );
        allotted = allotted.add(2_000_000 * 1e18);
        timeRelease = block.timestamp;
    }

    function addLiquidity(uint256 amountBUSD)
        public
        onlyRole(ADDLIQUIDITY_ROLE)
    {
        (uint256 amountA, uint256 amountB, ) = pancakeRouter.addLiquidity(
            address(token),
            busd,
            1_000_000_000 * 1e18,
            amountBUSD,
            0,
            0,
            address(this),
            block.timestamp
        );
        require(amountB == amountBUSD, "Must exact BUSD Liquidity");
        require(capped.sub(allotted) >= amountA, "Must be have liquidity fund");
        allotted = allotted.add(amountA);
    }
}
