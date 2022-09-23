// SPDX-License-Identifier: Viral Public License
pragma solidity ^0.8.0;

import "./interfaces/IAddressStorage.sol";
import "./interfaces/ISpellParams.sol";

contract SpellParams is ISpellParams {
    IAddressStorage public addressStorage;

    constructor(address _addressStorage) {
        addressStorage = IAddressStorage(_addressStorage);
    }

    function witherCost(uint256 target) public override returns (uint256) {
        return 0;
    }

    function defendCost(uint256 target) public override returns (uint256) {
        return 0;
    }

    function vitalityCost(uint256 target) public override returns (uint256) {
        return 0;
    }

    function rejuveCost(uint256 ageInVinegar)
        public
        override
        returns (uint256)
    {
        return 3 * ageInVinegar;
    }
}
