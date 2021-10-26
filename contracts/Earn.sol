//V2
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract Earn is AccessControl {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    event Stake(address indexed user, uint256 indexed fid, uint256 amount);
    event EmergencyUnstake(
        address indexed user,
        uint256 indexed fid,
        uint256 amount
    );
    event NewStartAndEndBlocks(
        uint256 indexed fid,
        uint256 startBlock,
        uint256 endBlock
    );
    event NewRewardPerBlock(uint256 indexed fid, uint256 rewardPerBlock);
    event NewFarmLimit(uint256 indexed fid, uint256 limitPerUser);
    event RewardsStop(uint256 indexed fid, uint256 blockNumber);
    event Unstake(address indexed user, uint256 indexed fid, uint256 amount);
    event NewFarm(uint256 indexed fid, address indexed tokenStake);

    //Config token reward PRL
    IERC20 public tokenReward;

    struct Farm {
        IERC20 tokenStake;
        uint256 startBlock;
        uint256 endBlock;
        uint256 lastRewardBlock;
        uint256 rewardPerShare;
        uint256 tokenRewardPerBlock;
        uint256 limitPerUser;
        uint256 totalStake;
    }

    struct UserInfo {
        uint256 amount;
        uint256 rewardDebt;
    }

    mapping(uint256 => mapping(address => UserInfo)) public userInfo;

    Farm[] public farms;

    constructor(address _tokenReward) {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        tokenReward = IERC20(_tokenReward);
    }

    function updateFarm(uint256 _fid) internal {
        Farm storage farm = farms[_fid];
        if (block.number <= farm.lastRewardBlock) {
            return;
        }
        if (farm.totalStake == 0) {
            farm.lastRewardBlock = block.number;
            return;
        }

        uint256 rewardAdded = (
            _getRangeBlock(farm.endBlock, farm.lastRewardBlock, block.number)
        ).mul(farm.tokenRewardPerBlock);
        farm.rewardPerShare = farm.rewardPerShare.add(
            rewardAdded.div(farm.totalStake)
        );
        farm.lastRewardBlock = block.number;
    }

    function stake(uint256 _fid, uint256 _amount) external {
        Farm storage farm = farms[_fid];
        UserInfo storage user = userInfo[_fid][msg.sender];
        require(
            farm.limitPerUser == 0 ||
                user.amount.add(_amount) <= farm.limitPerUser,
            "User amount above limit"
        );
        updateFarm(_fid);
        if (user.amount > 0) {
            uint256 pending = user.amount.mul(farm.rewardPerShare).sub(
                user.rewardDebt
            );
            if (pending > 0) {
                tokenReward.safeTransfer(address(msg.sender), pending);
            }
        }

        if (_amount > 0) {
            user.amount = user.amount.add(_amount);
            farm.totalStake = farm.totalStake.add(_amount);
            farm.tokenStake.safeTransferFrom(
                address(msg.sender),
                address(this),
                _amount
            );
        }

        user.rewardDebt = user.amount.mul(farm.rewardPerShare);

        emit Stake(msg.sender, _fid, _amount);
    }

    function unstake(uint256 _fid, uint256 _amount) external {
        Farm storage farm = farms[_fid];
        UserInfo storage user = userInfo[_fid][msg.sender];
        require(user.amount >= _amount, "Amount to unStake too high");

        updateFarm(_fid);

        uint256 pending = user.amount.mul(farm.rewardPerShare).sub(
            user.rewardDebt
        );

        if (_amount > 0) {
            user.amount = user.amount.sub(_amount);
            farm.totalStake = farm.totalStake.sub(_amount);
            farm.tokenStake.safeTransfer(address(msg.sender), _amount);
        }

        if (pending > 0) {
            tokenReward.safeTransfer(address(msg.sender), pending);
        }

        user.rewardDebt = user.amount.mul(farm.rewardPerShare);

        emit Unstake(msg.sender, _fid, _amount);
    }

    function emergencyUnstake(uint256 _fid) external {
        Farm storage farm = farms[_fid];
        UserInfo storage user = userInfo[_fid][msg.sender];
        uint256 amount = user.amount;
        user.amount = 0;
        user.rewardDebt = 0;

        if (amount > 0) {
            farm.tokenStake.safeTransfer(address(msg.sender), amount);
        }

        emit EmergencyUnstake(msg.sender, _fid, amount);
    }

    function stopReward(uint256 _fid) external onlyRole(DEFAULT_ADMIN_ROLE) {
        farms[_fid].endBlock = block.number;
        emit RewardsStop(_fid, block.number);
    }

    function updatePoolLimitPerUser(uint256 _fid, uint256 _poolLimitPerUser)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        farms[_fid].limitPerUser = _poolLimitPerUser;
        emit NewFarmLimit(_fid, _poolLimitPerUser);
    }

    function updateRewardPerBlock(uint256 _fid, uint256 _rewardPerBlock)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        Farm storage farm = farms[_fid];
        require(block.number < farm.startBlock, "Pool has started");
        farm.tokenRewardPerBlock = _rewardPerBlock;
        emit NewRewardPerBlock(_fid, _rewardPerBlock);
    }

    function updateStartAndEndBlocks(
        uint256 _fid,
        uint256 _startBlock,
        uint256 _endBlock
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        Farm storage farm = farms[_fid];
        require(block.number < farm.startBlock, "Pool has started");
        require(
            _startBlock < _endBlock,
            "New startBlock must be lower than new endBlock"
        );
        require(
            block.number < _startBlock,
            "New startBlock must be higher than current block"
        );

        farm.startBlock = _startBlock;
        farm.endBlock = _endBlock;
        farm.lastRewardBlock = _startBlock;

        emit NewStartAndEndBlocks(_fid, _startBlock, _endBlock);
    }

    function pendingReward(uint256 _fid, address _user)
        external
        view
        returns (uint256)
    {
        Farm memory farm = farms[_fid];
        UserInfo memory user = userInfo[_fid][_user];
        uint256 rewardPerShare = farm.rewardPerShare;
        if (block.number > farm.lastRewardBlock && farm.totalStake != 0) {
            uint256 rewardAdded = (
                _getRangeBlock(
                    farm.endBlock,
                    farm.lastRewardBlock,
                    block.number
                )
            ).mul(farm.tokenRewardPerBlock);
            rewardPerShare = rewardPerShare.add(
                rewardAdded.div(farm.totalStake)
            );
        }
        return user.amount.mul(rewardPerShare).sub(user.rewardDebt);
    }

    function addFarm(
        IERC20 _tokenStake,
        uint256 _rewardPerBlock,
        uint256 _startBlock,
        uint256 _endBlock,
        uint256 _limitPerUser
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        farms.push(
            Farm(
                _tokenStake,
                _startBlock,
                _endBlock,
                _startBlock,
                0,
                _rewardPerBlock,
                _limitPerUser,
                0
            )
        );
        emit NewFarm(farms.length - 1, address(_tokenStake));
    }

    function _getRangeBlock(
        uint256 _endBlock,
        uint256 _from,
        uint256 _to
    ) internal pure returns (uint256) {
        if (_to <= _endBlock) {
            return _to.sub(_from);
        } else if (_from >= _endBlock) {
            return 0;
        } else {
            return _endBlock.sub(_from);
        }
    }

    function manyFarm() external view returns (uint256) {
        return farms.length;
    }
}
