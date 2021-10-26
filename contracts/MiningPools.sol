//V1
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./IProxy.sol";

interface Mint {
    function mint(address to, uint256 amount) external;
}

contract MiningPools is AccessControl {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    bytes32 public constant DISTRIBUTOR_ROLE = keccak256("DISTRIBUTOR_ROLE");
    mapping(uint256 => uint256) public material;
    IProxy public proxy;

    function _initMaterial() private {
        material[0] = 1;
        material[1] = 10;
        material[2] = 10;
        material[3] = 10;
        material[4] = 10;
        material[5] = 150;
        material[6] = 150;
        material[7] = 200;
        material[8] = 1500;
        material[9] = 1500;
        material[10] = 1750;
        material[11] = 2000;
    }

    //User Info
    struct UserInfo {
        uint256 amount;
        uint256 rewardDebt;
        uint256 balance;
    }

    //MineInfo
    struct MineInfo {
        uint256 totalSupply;
        uint256 lastRewardBlock;
        uint256 pointPerShare;
        uint256 startBlock;
        uint256[12] materialsOutput;
        uint256[12] exchanged;
        uint256[12] oldOutput;
    }

    //Token for stake
    IERC20 public token;
    //Mine Info
    MineInfo[] public mineInfo;
    //User Info
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;

    event Stake(address indexed user, uint256 indexed mid, uint256 amount);
    event UnStake(address indexed user, uint256 indexed mid, uint256 amount);
    event NewMine(uint256 indexed mid, uint256[12] materialsOutput);
    event MineOutputChange(uint256 indexed mid, uint256[12] materialsOutput);

    constructor(address _token, address _proxy) {
        proxy = IProxy(_proxy);
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        token = IERC20(_token);
        _initMaterial();
    }

    function setWeightMaterial(uint256 index, uint256 weight)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        material[index] = weight;
    }

    function getAvailableMaterials(uint256 _mid)
        public
        view
        returns (uint256[12] memory output)
    {
        MineInfo storage mine = mineInfo[_mid];
        if (block.number <= mine.startBlock || _mid >= mineInfo.length)
            return output;
        uint256 numberBlock = block.number.sub(mine.startBlock);
        for (uint256 i = 0; i < 12; i++) {
            output[i] = mine
                .materialsOutput[i]
                .mul(numberBlock)
                .div(1e9)
                .sub(mine.exchanged[i])
                .add(mine.oldOutput[i]);
        }
    }

    function getMineOutput(uint256 _mid)
        public
        view
        returns (uint256[12] memory)
    {
        return mineInfo[_mid].materialsOutput;
    }

    function exchange(uint256 _mid, uint256[12] memory amount) public {
        MineInfo storage mine = mineInfo[_mid];
        UserInfo storage user = userInfo[_mid][msg.sender];
        uint256 point;
        for (uint256 i = 0; i < 12; i++) {
            point = point.add(amount[i].mul(material[i]));
        }
        point = point * 1e18;
        require(user.balance >= point, "Must be have point to exchange");
        uint256[12] memory available = getAvailableMaterials(_mid);
        user.balance = user.balance.sub(point);
        for (uint256 j = 0; j < 12; j++) {
            if (amount[j] > 0) {
                require(available[j] >= amount[j], "Run out material");
                mine.exchanged[j] = mine.exchanged[j].add(amount[j]);
                Mint(proxy.getRuneAddress(j)).mint(msg.sender, amount[j]);
            }
        }
    }

    function addMine(uint256 startBlock, uint256[12] memory materialsOutput)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
        returns (uint256)
    {
        uint256 lastRewardBlock = block.number > startBlock
            ? block.number
            : startBlock;
        mineInfo.push(
            MineInfo(
                0,
                lastRewardBlock,
                0,
                startBlock,
                materialsOutput,
                [uint256(0), 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
                [uint256(0), 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
            )
        );
        emit NewMine(mineInfo.length - 1, materialsOutput);
        return mineInfo.length - 1;
    }

    // Stake tokens to Mine.
    function stake(uint256 _mid, uint256 _amount) public {
        MineInfo storage mine = mineInfo[_mid];
        UserInfo storage user = userInfo[_mid][msg.sender];
        updateMine(_mid);
        if (user.amount > 0) {
            uint256 pending = user.amount.mul(mine.pointPerShare).sub(
                user.rewardDebt
            );
            if (pending > 0) {
                user.balance = user.balance.add(pending);
            }
        }
        if (_amount > 0) {
            token.safeTransferFrom(address(msg.sender), address(this), _amount);
            user.amount = user.amount.add(_amount);
            mine.totalSupply = mine.totalSupply.add(_amount);
        }
        user.rewardDebt = user.amount.mul(mine.pointPerShare);
        emit Stake(msg.sender, _mid, _amount);
    }

    function transferPoint(
        uint256 _mid,
        uint256 _amount,
        address _receiver
    ) external {
        require(_mid < mineInfo.length, "Mine Id invalid");
        UserInfo storage user = userInfo[_mid][msg.sender];
        require(user.balance >= _amount, "Not enough point for transfer");
        user.balance = user.balance.sub(_amount);
        userInfo[_mid][_receiver].balance = userInfo[_mid][_receiver]
            .balance
            .add(_amount);
    }

    // Unstake tokens from Mine.
    function unstake(uint256 _mid, uint256 _amount) public {
        MineInfo storage mine = mineInfo[_mid];
        UserInfo storage user = userInfo[_mid][msg.sender];
        require(user.amount >= _amount, "unstake: not have");
        updateMine(_mid);

        uint256 pending = user.amount.mul(mine.pointPerShare).sub(
            user.rewardDebt
        );
        if (pending > 0) {
            user.balance = user.balance.add(pending);
        }
        if (_amount > 0) {
            user.amount = user.amount.sub(_amount);
            mine.totalSupply = mine.totalSupply.sub(_amount);
            token.safeTransfer(address(msg.sender), _amount);
        }
        user.rewardDebt = user.amount.mul(mine.pointPerShare);
        emit UnStake(msg.sender, _mid, _amount);
    }

    function pendingPoint(uint256 _mid, address _user)
        external
        view
        returns (uint256)
    {
        MineInfo memory mine = mineInfo[_mid];
        UserInfo memory user = userInfo[_mid][_user];
        uint256 pointPerShare = mine.pointPerShare;
        if (block.number > mine.lastRewardBlock && mine.totalSupply != 0) {
            uint256 pointAdded = ((block.number).sub(mine.lastRewardBlock))
                .mul(getTotalPointPerBlock(_mid))
                .div(1e9);
            pointPerShare = mine.pointPerShare.add(
                pointAdded.div(mine.totalSupply)
            );
        }
        return user.amount.mul(pointPerShare).sub(user.rewardDebt);
    }

    function updateMineOutput(uint256 _mid, uint256[12] memory materialsOutput)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        MineInfo storage mine = mineInfo[_mid];
        updateMine(_mid);
        uint256[12] memory oldOutput = getAvailableMaterials(_mid);
        for (uint256 i = 0; i < 12; i++) {
            mine.oldOutput[i] = oldOutput[i] + mine.exchanged[i];
        }
        mine.materialsOutput = materialsOutput;
        mine.startBlock = block.number;
        emit MineOutputChange(_mid, materialsOutput);
    }

    //Get total point per block mul 1e9
    function getTotalPointPerBlock(uint256 _mid) public view returns (uint256) {
        uint256 totalPoint = 0;
        uint256[12] memory materialsOutput = mineInfo[_mid].materialsOutput;
        for (uint256 i = 0; i < 12; i++) {
            totalPoint = totalPoint.add(materialsOutput[i].mul(material[i]));
        }
        return totalPoint * 1e18;
    }

    // Mine update.
    function updateMine(uint256 _mid) public {
        MineInfo storage mine = mineInfo[_mid];
        if (block.number <= mine.lastRewardBlock) {
            return;
        }
        if (mine.totalSupply == 0) {
            mine.lastRewardBlock = block.number;
            return;
        }
        uint256 pointAdded = ((block.number).sub(mine.lastRewardBlock))
            .mul(getTotalPointPerBlock(_mid))
            .div(1e9);
        mine.pointPerShare = mine.pointPerShare.add(
            pointAdded.div(mine.totalSupply)
        );
        mine.lastRewardBlock = block.number;
    }

    // Unstake without caring about rewards. EMERGENCY ONLY.
    function emergencyUnstake(uint256 _mid) public {
        UserInfo memory user = userInfo[_mid][msg.sender];
        token.safeTransfer(address(msg.sender), user.amount);
        emit UnStake(msg.sender, _mid, user.amount);
        user.amount = 0;
        user.rewardDebt = 0;
    }

    function manyMine() external view returns (uint256) {
        return mineInfo.length;
    }
}
