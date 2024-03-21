// SPDX-License-Identifier: UNLICENSED

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/IAccessControl.sol";

pragma solidity ^0.8.24;

interface IRewardToken {
    function mint(address _to, uint256 _amount) external;
}
