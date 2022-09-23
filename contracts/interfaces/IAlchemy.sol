// SPDX-License-Identifier: Viral Public License
pragma solidity ^0.8.0;

interface IAlchemy {
    enum Spell {
        WITHER,
        DEFEND,
        VITALITY
    }
    struct Withering {
        uint256 deadline;
        uint256 season;
    }

    function withered(uint256 target)
        external
        view
        returns (uint256 deadline, uint256 season);

    function vitalized(uint256 target) external view returns (uint256);
}
