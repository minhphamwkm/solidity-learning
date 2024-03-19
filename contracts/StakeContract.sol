// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.24;

/*
Viết contract upgradeable staking token:
    V1:
        + Cho phép user stake coin vào contract
        + Duration sẽ được pick theo 3 gói:
            - 30 ngày, APR: 10%
            - 60 ngày, APR: 20%
            - 90 ngày, APR: 30%
        + User có thể unstake token sau khi hết duration
        + Trong thời gian staking, user có thể claim reward, tốc độ reward là 1s/1 token * số lượng stake.
        + Token reward sẽ được mint từ contract khi user claim reward
    V2:
        + Update lại contract, token reward có giới hạn
        + Owner sẽ mint token reward riêng và deposit vào contract staking
        + Nếu số token reward user có thể claim vượt balance của contract, user sẽ claim được tối đa = balance của contract, phần thừa sẽ để tích trữ lại cho lần claim sau
Vi du:
stake 0.1 ETH - 30 ngay - 10%
    - sau 30 ngay: unstake, nhan ve 0.1 * 110%
    - trong 30 ngay:
        + ngay thu 5: claim reward, so luong reward nhan duoc: 1 * 0.1 * 5 * 60 * 60 * 24
        + ngay thu 7: claim reward, so luong reward nhan duoc: 1 * 0.1 * 2 * 60 * 60 * 24
    - ngay thu 30: unstake
    - Claim reward:
        + quote: 1 * 0.1 * 23 * 60 * 60 * 24
V2:
    - Owner mint 100 dong token reward
    - Owner deposit 100 dong vao contract
    - 150s sau: user claim reward
            + quote: 150$
            + contract balance: 100$
            + user claim: 100$ - 100s
    - 50s sau: user claim reward
            + quote: 100$
            + claim: fail
    - Owner mint 1000$ -> deposit 1000$ vao contract

    - neu claim time < duration: claim = claim time
*/

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "hardhat/console.sol";

contract RewardToken is ERC20 {
    constructor() ERC20("RewardToken", "RWT") {}

    function mint(address _to, uint256 _amount) external {
        _mint(_to, _amount);
    }
}

interface IRewardToken {
    function mint(address _to, uint256 _amount) external;
}

contract StakeContract is Initializable, UUPSUpgradeable, OwnableUpgradeable {
    uint256 balance;

    struct Stake {
        uint256 amount;
        uint256 duration;
        uint8 apr;
        uint256 startTime;
        uint256 endTime;
        uint256 rewardClaimedBySecond;
        bool isUnstaked;
    }

    mapping(address => Stake[]) public stakes;

    event NewStake(
        address user,
        uint256 amount,
        uint256 duration,
        uint8 apr,
        uint256 startTime,
        uint256 endTime,
        uint256 stakeIndex
    );
    event Unstake(address user, uint256 total, uint256 unstakeTime);
    event ClaimReward(address user, uint256 reward, uint256 claimTime);

    constructor() {
        _disableInitializers();
    }

    function initialize() public initializer {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}

    function getAllStakes() public view returns (Stake[] memory) {
        return stakes[msg.sender];
    }

    function getStake(uint256 _index) public view returns (Stake memory) {
        return stakes[msg.sender][_index];
    }

    function deposit() public payable onlyOwner {
        balance += msg.value;
    }

    function _mint(address _account, uint256 _value) internal onlyOwner {
        require(_account != address(0), "Mint to the zero address");
        IRewardToken(owner()).mint(_account, _value);
    }

    function stake(uint8 _duration) public payable {
        require(
            _duration == 30 || _duration == 60 || _duration == 90,
            "Invalid duration"
        );
        require(msg.value > 0, "Invalid amount");

        balance += msg.value;

        uint8 apr;
        if (_duration == 30) {
            apr = 10;
        } else if (_duration == 60) {
            apr = 20;
        } else {
            apr = 30;
        }

        uint256 endTime = block.timestamp + uint256(_duration) * 24 * 60 * 60;

        stakes[msg.sender].push(
            Stake(msg.value, _duration, apr, block.timestamp, endTime, 0, false)
        );

        emit NewStake(
            msg.sender,
            msg.value,
            _duration,
            apr,
            block.timestamp,
            endTime,
            stakes[msg.sender].length - 1
        );
    }

    function unstake(uint256 _index) public payable {
        require(_index < stakes[msg.sender].length, "Invalid stake index");
        require(!stakes[msg.sender][_index].isUnstaked, "Already unstaked");
        require(
            block.timestamp >= stakes[msg.sender][_index].endTime,
            "Stake not completed yet"
        );

        uint256 total = calculateUnstakeTotal(_index);

        require(
            balance >= total,
            "Insufficient balance, contact admin to unstake"
        );

        payable(msg.sender).transfer(total);
        stakes[msg.sender][_index].isUnstaked = true;
        balance -= total;
        emit Unstake(msg.sender, total, block.timestamp);
    }

    function claimReward(uint256 _index) public {
        require(_index < stakes[msg.sender].length, "Invalid stake index");
        uint256 claimTime = block.timestamp;
        (uint256 remainTime, uint256 reward) = calculateRemainReward(
            stakes[msg.sender][_index],
            claimTime
        );

        _mint(msg.sender, reward);

        stakes[msg.sender][_index].rewardClaimedBySecond += remainTime;
        emit ClaimReward(msg.sender, reward, claimTime);
    }

    function calculateUnstakeTotal(
        uint256 _index
    ) private view returns (uint256) {
        return
            (stakes[msg.sender][_index].amount *
                (uint256(stakes[msg.sender][_index].apr) + 100)) / 100;
    }

    function calculateRemainReward(
        Stake memory _stake,
        uint256 _claimTime
    ) private pure returns (uint256, uint256) {
        uint256 remainTime = (
            _stake.duration > _claimTime - _stake.startTime
                ? _claimTime - _stake.startTime
                : _stake.duration
        );
        uint256 reward = (remainTime - _stake.rewardClaimedBySecond) *
            _stake.amount;
        return (remainTime, reward);
    }
}

// contract StakeContractV2 is Initializable, UUPSUpgradeable, OwnableUpgradeable{
//     uint256 balance;

//     struct Stake {
//         uint256 amount;
//         uint8 duration;
//         uint256 startTime;
//         uint256 rewardClaimedBySecond;
//         bool isUnstaked;
//     }

//     uint256 public rewardBalance;

//     mapping(address => Stake[]) public stakes;
//     mapping(uint8 => uint256) public durationToAPR;

//     event NewStake(address user, uint256 amount, uint8 duration, uint256 startTime, uint256 stakeIndex);
//     event Unstake(address user, uint256 total, uint256 unstakeTime);
//     event ClaimReward(address user, uint256 reward, uint256 claimTime);

//     constructor() {
//         _disableInitializers();
//     }

//     function initialize() initializer public {
//         __Ownable_init(msg.sender);
//         __UUPSUpgradeable_init();

//         durationToAPR[30] = 10;
//         durationToAPR[60] = 20;
//         durationToAPR[90] = 30;
//     }

//     function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

//     function getAllStakes(address _user) public view returns (Stake[] memory) {
//         return stakes[_user];
//     }

//     function getStake(address _user, uint256 _index)
//         external
//         view
//         returns (Stake memory)
//     {
//         return stakes[_user][_index];
//     }

//     function deposit() public payable onlyOwner {
//         balance += msg.value;
//     }

//     function depositReward(uint256 _amount) public onlyOwner {
//         IERC20(address(this)).transferFrom(msg.sender, address(this), _amount);
//         rewardBalance += _amount;
//     }

//     function stake(uint8 _duration) external payable {
//         require(
//             _duration == 30 || _duration == 60 || _duration == 90,
//             "Invalid duration"
//         );

//         balance += msg.value;
//         stakes[msg.sender].push(
//             Stake(msg.value, _duration, block.timestamp, 0, false)
//         );

//         emit NewStake(msg.sender, msg.value, _duration, block.timestamp, stakes[msg.sender].length - 1);
//     }

//     function unstake(uint256 _index) external {
//         require(_index < stakes[msg.sender].length, "Invalid stake index");
//         require(!stakes[msg.sender][_index].isUnstaked, "Already unstaked");
//         require(
//             block.timestamp >=
//                 stakes[msg.sender][_index].startTime +
//                     stakes[msg.sender][_index].duration,
//             "Stake not completed yet"
//         );

//         uint256 total = calculateUnstakeTotal(_index);

//         require(balance >= total, "Insufficient balance, contact admin to unstake");

//         payable(msg.sender).transfer(total);

//         stakes[msg.sender][_index].isUnstaked = true;
//         emit Unstake(msg.sender, total, block.timestamp);
//     }

//     function claimReward(uint256 _index) external {
//         require(_index < stakes[msg.sender].length, "Invalid stake index");
//         uint256 claimTime = block.timestamp;
//         (uint256 remainTime,uint256 reward) = calculateRemainReward(stakes[msg.sender][_index], claimTime);

//         // _mint(msg.sender, reward);

//         stakes[msg.sender][_index].rewardClaimedBySecond += remainTime;
//         emit ClaimReward(msg.sender, reward, claimTime);
//     }

//     function calculateUnstakeTotal(uint256 _index) private view returns (uint256) {
//         return stakes[msg.sender][_index].amount * (durationToAPR[stakes[msg.sender][_index].duration] / 100);
//     }

//     function calculateRemainReward(
//         Stake memory _stake, uint256 _claimTime
//     ) private pure returns (uint256, uint256) {
//         uint256 remainTime = (_stake.duration > _claimTime - _stake.startTime ? _claimTime - _stake.startTime : _stake.duration );
//         uint256 reward = ( remainTime - _stake.rewardClaimedBySecond) * _stake.amount;
//         return (remainTime, reward);
//     }
// }
