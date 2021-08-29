//SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "./IAddressStorage.sol";

contract AddressStorage is IAddressStorage {
    address public override cellar;
    address public override vinegar;
    address public override vineyard;
    address public override bottle;

    bool private addressesSet = false;
    address private deployer;

    event AddressesSet();

    constructor() {
      deployer = msg.sender;
    }

    function setAddresses(
        address _cellar,
        address _vinegar,
        address _vineyard,
        address _bottle
    ) public {
        require(addressesSet == false, "already set");
        require(msg.sender == deployer, "not deployer");
        cellar = _cellar;
        vinegar = _vinegar;
        vineyard = _vineyard;
        bottle = _bottle;
        addressesSet = true;
        emit AddressesSet();
    }
}
