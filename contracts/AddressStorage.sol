//SPDX-License-Identifier: Viral Public License
pragma solidity ^0.8.0;

import "./interfaces/IAddressStorage.sol";
import "../node_modules/@openzeppelin/contracts/access/Ownable.sol";

contract AddressStorage is IAddressStorage, Ownable {
    address public override cellar;
    address public override vinegar;
    address public override vineyard;
    address public override bottle;
    address public override giveawayToken;
    address public override royaltyManager;
    address public override merkle;

    bool private addressesSet = false;

    // EVENTS
    event AddressesSet();

    // CONSTRUCTOR
    constructor() Ownable() {}

    // PUBLIC FUNCTIONS
    /// @notice sets addresses for ecosystem
    function setAddresses(
        address _cellar,
        address _vinegar,
        address _vineyard,
        address _bottle,
        address _giveawayToken,
        address _royaltyManager,
        address _merkle
    ) public {
        require(addressesSet == false, "already set");
        require(msg.sender == owner(), "not deployer");
        cellar = _cellar;
        vinegar = _vinegar;
        vineyard = _vineyard;
        bottle = _bottle;
        giveawayToken = _giveawayToken;
        royaltyManager = _royaltyManager;
        merkle = _merkle;
        addressesSet = true;
        emit AddressesSet();
    }

    function newRoyaltyManager(address _royaltyManager) external onlyOwner {
        royaltyManager = _royaltyManager;
        emit AddressesSet();
    }
}
