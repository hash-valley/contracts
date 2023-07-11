// SPDX-License-Identifier: Viral Public License
pragma solidity ^0.8.0;

import "./interfaces/IAddressStorage.sol";
import "./interfaces/IGrape.sol";
import "./interfaces/IVinegar.sol";
import "./interfaces/IAlchemy.sol";
import "./interfaces/ISpellParams.sol";

interface IVine {
    function currSeason() external view returns (uint256);

    function plantingTime() external view returns (bool);
}

contract Alchemy is IAlchemy {
    IAddressStorage public addressStorage;

    mapping(uint256 => Withering) public withered;
    mapping(uint256 => uint256) public vitalized;

    event Wither(uint256 target, uint256 deadline, uint256 cost);
    event Defend(uint256 target, uint256 cost);
    event Vitality(uint256 target, uint256 cost);

    constructor(address _addressStorage) {
        addressStorage = IAddressStorage(_addressStorage);
    }

    /// @notice disable vineyard for season
    function wither(uint256 target) public {
        require(withered[target].deadline == 0, "already withering");
        uint256 deadline = block.timestamp + 16 hours;
        uint256 cost = ISpellParams(addressStorage.spellParams()).witherCost(
            target
        );
        withered[target] = Withering(
            deadline,
            IVine(addressStorage.vineyard()).currSeason()
        );
        IVinegar(addressStorage.vinegar()).witherCost(msg.sender, cost);
        emit Wither(target, deadline, cost);
    }

    /// @notice blocks a wither
    function defend(uint256 target) public {
        require(
            withered[target].deadline >= block.timestamp &&
                withered[target].deadline != 0,
            "!withering"
        );
        uint256 cost = ISpellParams(addressStorage.spellParams()).defendCost(
            target
        );
        delete withered[target];
        IGrape(addressStorage.grape()).burn(msg.sender, cost);
        emit Defend(target, cost);
    }

    /// @notice burns grapes to boost xp gain on vineyard
    function vitality(uint256 target) public {
        uint256 currSeason = IVine(addressStorage.vineyard()).currSeason();
        require(vitalized[target] != currSeason, "already vitalized");
        require(
            IVine(addressStorage.vineyard()).plantingTime(),
            "!plantingTime"
        );
        vitalized[target] = currSeason;
        uint256 cost = ISpellParams(addressStorage.spellParams()).vitalityCost(
            target
        );
        IGrape(addressStorage.grape()).burn(msg.sender, cost);
        emit Vitality(target, cost);
    }

    function batchSpell(uint256[] calldata targets, uint8 spell) public {
        for (uint8 i = 0; i < targets.length; i++) {
            if (spell == 0) wither(targets[i]);
            if (spell == 1) defend(targets[i]);
            if (spell == 2) vitality(targets[i]);
        }
    }
}
