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
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import "hardhat/console.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

import "./interfaces/IRewardToken.sol";

contract StakeContract is Initializable, UUPSUpgradeable, OwnableUpgradeable {
    address public rewardToken;

    enum PACKAGES {
        D30,
        D60,
        D90
    }

    struct PackageData {
        uint256 duration;
        uint256 apr;
    }
    struct Stake {
        uint256 amount;
        PackageData package;
        uint256 startAt;
        uint256 endAt;
        uint256 lastClaimedAt;
        bool isUnstaked;
    }

    mapping(PACKAGES => PackageData) public packages;
    mapping(address => Stake[]) public stakes;

    event NewStake(
        address user,
        uint256 amount,
        PackageData package,
        uint256 startAt,
        uint256 endAt,
        uint256 stakeIndex
    );

    modifier validStake(uint256 _stakeIndex) {
        require(_stakeIndex < stakes[msg.sender].length, "Invalid stake index");
        _;
    }

    function initialize() public initializer {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();

        packages[PACKAGES.D30] = PackageData(30, 10);
        packages[PACKAGES.D60] = PackageData(60, 20);
        packages[PACKAGES.D90] = PackageData(90, 30);
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

    function getAllPackages() public view returns (PackageData[] memory) {
        PackageData[] memory result = new PackageData[](3);
        result[0] = packages[PACKAGES.D30];
        result[1] = packages[PACKAGES.D60];
        result[2] = packages[PACKAGES.D90];
        return result;
    }

    function setRewardToken(address _rewardToken) public onlyOwner {
        rewardToken = _rewardToken;
    }

    function stake(PACKAGES _package) public payable {
        require(msg.value > 0, "Invalid amount");

        uint256 endAt = block.timestamp + packages[_package].duration * 1 days;

        stakes[msg.sender].push(
            Stake(
                msg.value,
                packages[_package],
                block.timestamp,
                endAt,
                block.timestamp,
                false
            )
        );

        emit NewStake(
            msg.sender,
            msg.value,
            packages[_package],
            block.timestamp,
            endAt,
            stakes[msg.sender].length - 1
        );
    }

    function unstake(uint256 _index) public payable validStake(_index) {
        require(!stakes[msg.sender][_index].isUnstaked, "Already unstaked");
        require(
            block.timestamp >= stakes[msg.sender][_index].endAt,
            "Stake not completed yet"
        );

        uint256 total = _calculateUnstakeTotal(_index);

        require(
            address(this).balance >= total,
            "Insufficient balance, contact admin to unstake"
        );

        payable(msg.sender).transfer(total);
        stakes[msg.sender][_index].isUnstaked = true;
    }

    function claimReward(uint256 _index) public validStake(_index) {
        uint256 reward = _calculateRemainReward(
            stakes[msg.sender][_index],
            block.timestamp
        );

        _mint(msg.sender, reward);

        stakes[msg.sender][_index].lastClaimedAt = block.timestamp;
    }

    function _calculateUnstakeTotal(
        uint256 _index
    ) private view returns (uint256) {
        return
            (stakes[msg.sender][_index].amount *
                (stakes[msg.sender][_index].package.apr + 100)) / 100;
    }

    function _calculateRemainReward(
        Stake memory _stake,
        uint256 _claimTime
    ) private pure returns (uint256 reward) {
        uint256 remainTime = Math.min(_stake.endAt, _claimTime) -
            _stake.lastClaimedAt;
        reward = (remainTime * _stake.amount) / 100_000;
    }

    function _mint(address _account, uint256 _value) private {
        IRewardToken(rewardToken).mint(_account, _value);
    }

    receive() external payable {}
    fallback() external payable {}
}
