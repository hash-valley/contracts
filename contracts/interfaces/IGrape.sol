// SPDX-License-Identifier: Viral Public License
pragma solidity ^0.8.0;

interface IGrape {
    function burn(address caller, uint256 amount) external;

    function mint(address caller, uint256 amount) external;
}
