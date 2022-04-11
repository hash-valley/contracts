//SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.0;

import "../node_modules/@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./IAddressStorage.sol";

contract Vinegar is ERC20 {
    IAddressStorage public addressStorage;

    constructor(address _addressStorage) ERC20("Vinegar", "VNG") {
        addressStorage = IAddressStorage(_addressStorage);
    }

    /// @notice mints tokens to recipient who spoiled their bottle
    function spoilReward(address recipient, uint256 amount) public {
        require(msg.sender == addressStorage.cellar(), "not cellar");
        _mint(recipient, amount * 1e18);
    }

    /// @notice burns the specified amount of tokens
    function burn(address account, uint256 amount) public {
        require(msg.sender == addressStorage.bottle(), "Not Bottle");
        _burn(account, amount);
    }
}
