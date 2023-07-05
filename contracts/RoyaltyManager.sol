// SPDX-License-Identifier: Viral Public License
pragma solidity ^0.8.0;

import "./interfaces/IAddressStorage.sol";

interface QuixoticExchange {
    function setRoyalty(address _erc721address, address payable _payoutAddress, uint256 _payoutPerMille) external;
}

interface DefaultRoyalty {
    function setDefaultRoyalty(address _receiver, uint96 _feeNumerator) external;
}

contract RoyaltyManager {
    IAddressStorage private addressStorage;
    uint16 private immutable sellerFee = 500;

    constructor(address _addressStorage) {
        addressStorage = IAddressStorage(_addressStorage);
    }

    function updateRoyalties(address recipient) external {
        address bottle = addressStorage.bottle();
        address vine = addressStorage.vineyard();
        if (msg.sender == addressStorage.wineUri() || msg.sender == bottle) {
            DefaultRoyalty(bottle).setDefaultRoyalty(recipient, sellerFee);
        } else if (msg.sender == addressStorage.vineUri() || msg.sender == vine) {
            DefaultRoyalty(vine).setDefaultRoyalty(recipient, sellerFee);
        } else {
            revert("bad royalty");
        }
    }
}
