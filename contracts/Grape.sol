// SPDX-License-Identifier: Viral Public License
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./interfaces/IAddressStorage.sol";
import "./interfaces/IGrape.sol";

contract Grape is IGrape, ERC20 {
    IAddressStorage public addressStorage;

    constructor(address _addressStorage) ERC20("Grape", "GRAPE") {
        addressStorage = IAddressStorage(_addressStorage);
        _mint(_msgSender(), 1_000_000e18);
    }

    /// @notice mint grapes from eligible vineyard
    function mint(address caller, uint256 amount) public override {
        require(_msgSender() == addressStorage.vineyard(), "!vine");
        _mint(caller, amount);
    }

    /// @notice burns grapes for alchemy
    function burn(address caller, uint256 amount) public override {
        require(_msgSender() == addressStorage.alchemy(), "!alchemy");
        _burn(caller, amount);
    }
}
