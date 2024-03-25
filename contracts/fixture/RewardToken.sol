// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract RewardToken is ERC20, AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    error CallerNotMinter(address caller);

    constructor() ERC20("RewardToken", "RWT") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    modifier onlyMinter() {
        if (!hasRole(MINTER_ROLE, msg.sender))
            revert CallerNotMinter(msg.sender);
        _;
    }

    function grantMinterRole(
        address _minter
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        grantRole(MINTER_ROLE, _minter);
    }

    function mint(address _to, uint256 _amount) external onlyMinter {
        _mint(_to, _amount);
    }
}
