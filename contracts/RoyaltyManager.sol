//SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.0;

import "./interfaces/IAddressStorage.sol";

interface QuixoticExchange {
    function setRoyalty(
        address contractAddress,
        address payable _payoutAddress,
        uint256 _payoutPerMille
    ) external;
}

contract RoyaltyManager {
    IAddressStorage private addressStorage;
    QuixoticExchange private quixotic;
    uint16 private immutable sellerFee = 750;

    constructor(address _addressStorage, address _quixotic) {
        addressStorage = IAddressStorage(_addressStorage);
        quixotic = QuixoticExchange(_quixotic);
    }

    function updateRoyalties(address recipient) external {
        require(
            msg.sender == addressStorage.bottle() ||
                msg.sender == addressStorage.vineyard(),
            "invalid caller"
        );
        quixotic.setRoyalty(msg.sender, payable(recipient), sellerFee / 10);
    }
}
