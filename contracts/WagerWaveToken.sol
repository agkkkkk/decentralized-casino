// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract WagerWaveToken is ERC20, Ownable {
    constructor() ERC20("WagerWave", "WW") Ownable(msg.sender) {
        _mint(msg.sender, 10000 * 10 ** decimals());
    }

    // function mint(address _to, uint256 _amount) external onlyOwner {
    //     _mint(_to, _amount);
    // }

    // function burn(uint256 _amount) external {
    //     _burn(msg.sender, _amount);
    // }
}
