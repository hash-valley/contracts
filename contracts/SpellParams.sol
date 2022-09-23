// SPDX-License-Identifier: Viral Public License
pragma solidity ^0.8.0;

import "./interfaces/IAddressStorage.sol";
import "./interfaces/ISpellParams.sol";

interface ISeasons {
    function startOfSeason() external view returns (uint256, uint256);
}

contract SpellParams is ISpellParams {
    IAddressStorage public addressStorage;

    constructor(address _addressStorage) {
        addressStorage = IAddressStorage(_addressStorage);
    }

    /// @notice gets cheaper deeper into the season
    function witherCost(uint256 target) public view override returns (uint256) {
        (uint256 seasonStart, uint256 season) = ISeasons(
            addressStorage.vineyard()
        ).startOfSeason();

        uint256 timePassed = block.timestamp - seasonStart;
        return
            (15_000e18 * timePassed) /
            (season == 1 ? 3 weeks : 12 weeks) +
            5_000e18;
    }

    function defendCost(uint256 target) public view override returns (uint256) {
        return 2_000e18;
    }

    function vitalityCost(uint256 target)
        public
        view
        override
        returns (uint256)
    {
        return 1_660e18;
    }

    function rejuveCost(uint256 ageInVinegar)
        public
        view
        override
        returns (uint256)
    {
        return 3 * ageInVinegar;
    }
}
