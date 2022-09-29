// SPDX-License-Identifier: Viral Public License
pragma solidity ^0.8.0;

interface ISpellParams {
    function witherCost(uint256 target) external view returns (uint256);

    function defendCost(uint256 target) external view returns (uint256);

    function vitalityCost(uint256 target) external view returns (uint256);

    function rejuveCost(uint target) external view returns (uint256);
}
