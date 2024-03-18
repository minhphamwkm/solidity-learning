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
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract StakeContract is Ownable, ERC20 {
    uint256 balance;

    struct Stake {
        uint256 amount;
        uint8 duration;
        uint256 startTime;
        uint256 rewardClaimedBySecond;
        bool isUnstaked;
    }

    mapping(address => Stake[]) public stakes;

    mapping(uint8 => uint256) public durationToAPR;

    constructor() Ownable(msg.sender) ERC20("Stake", "STK") {
        durationToAPR[30] = 10;
        durationToAPR[60] = 20;
        durationToAPR[90] = 30;
    }

    function deposit() public payable onlyOwner {
        balance += msg.value;
    }

    function stake(uint8 _duration) external payable {
        require(
            _duration == 30 || _duration == 60 || _duration == 90,
            "Invalid duration"
        );

        balance += msg.value;
        stakes[msg.sender].push(
            Stake(msg.value, _duration, block.timestamp, 0, false)
        );
    }

    function unstake(uint256 _index) external {
        require(_index < stakes[msg.sender].length, "Invalid stake index");
        require(!stakes[msg.sender][_index].isUnstaked, "Already unstaked");
        require(
            block.timestamp >=
                stakes[msg.sender][_index].startTime +
                    stakes[msg.sender][_index].duration,
            "Stake not completed yet"
        );

        uint256 total = calculateUnstakeTotal(_index);
        payable(msg.sender).transfer(total);

        stakes[msg.sender][_index].isUnstaked = true;
    }

    function claimReward(uint256 _index) external {
        require(_index < stakes[msg.sender].length, "Invalid stake index");
        uint256 claimTime = block.timestamp;
        (uint256 remainTime,uint256 reward) = calculateRemainReward(stakes[msg.sender][_index], claimTime);

        _mint(msg.sender, reward);

        stakes[msg.sender][_index].rewardClaimedBySecond += remainTime;
    }

    function calculateUnstakeTotal(uint256 _index) private view returns (uint256) {
        return stakes[msg.sender][_index].amount * (durationToAPR[stakes[msg.sender][_index].duration] / 100);
    }

    function calculateRemainReward(
        Stake memory _stake, uint256 _claimTime
    ) private pure returns (uint256, uint256) {
        uint256 remainTime = (_stake.duration > _claimTime - _stake.startTime ? _claimTime - _stake.startTime : _stake.duration );
        uint256 reward = ( remainTime - _stake.rewardClaimedBySecond) * _stake.amount;
        return (remainTime, reward);
    }
}
