// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

// Uncomment this line to use console.log
// import "hardhat/console.sol";

// Deploy được contract trên mạng localhost:
//  + Contract token ERC20 có tên là "MyToken", symbol là "MTK", decimals là 18
//  + Tại lúc deploy, mint cho người deploy 1 triệu token (lưu ý là 1 triệu token đã được nhân với 10^18 vì số decimals là 18)

// Có tính năng owner: người sở hữu contract và có các quyền riêng biệt
// Chỉ owner mới được mint token cho 1 address bất kì với số lượng bất kì
// Chỉ owner mới được burn token của 1 address bất kì với số lượng bất kì

contract MyToken is ERC20, Ownable {
    constructor(address owner) Ownable(owner) ERC20("MyToken", "MTK") {
        _mint(owner, 1000000 * (10 ** uint256(decimals())));
    }

    function burn(address wallet, uint256 amount) public onlyOwner() {
        require(amount > 0, "Amount must be greater than zero");
        require(balanceOf(wallet) >= amount, "ERC20: burn amount exceeds balance");
        _burn(wallet, amount);
    }

    function mint(address wallet, uint256 amount) public onlyOwner() {
        require(amount > 0, "Amount must be greater than zero");
        _mint(wallet, amount);
    }
}