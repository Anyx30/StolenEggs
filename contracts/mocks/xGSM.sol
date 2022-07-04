// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract xGSM is ERC20, Ownable {
    constructor() ERC20("xGSM", "XGSM") {}

    function mint(uint256 amount) public {
        _mint(_msgSender(), amount);
    }
}