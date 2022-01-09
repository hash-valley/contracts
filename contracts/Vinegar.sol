//SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import "./IAddressStorage.sol";

contract Vinegar is ERC20, ERC20Permit {
    IAddressStorage public addressStorage;

    constructor(address _addressStorage)
        ERC20("Vinegar", "VNG")
        ERC20Permit("Vinegar")
    {
        addressStorage = IAddressStorage(_addressStorage);
    }

    function spoilReward(address recipient, uint256 amount) public {
        require(msg.sender == addressStorage.cellar(), "not cellar");
        _mint(recipient, amount * 1e18);
    }

    function burn(address account, uint256 amount) public {
        require(msg.sender == addressStorage.bottle(), "Not Bottle");
        _burn(account, amount);
    }
}
