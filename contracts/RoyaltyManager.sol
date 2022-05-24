//SPDX-License-Identifier: Viral Public License
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
        address bottle = addressStorage.bottle();
        address vine = addressStorage.vineyard();
        if (msg.sender == addressStorage.wineUri() || msg.sender == bottle) {
            quixotic.setRoyalty(bottle, payable(recipient), sellerFee / 10);
        } else if (
            msg.sender == addressStorage.vineUri() || msg.sender == vine
        ) {
            quixotic.setRoyalty(vine, payable(recipient), sellerFee / 10);
        } else {
            revert("bad royalty");
        }
    }
}
