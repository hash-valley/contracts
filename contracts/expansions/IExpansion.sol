//SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.0;

interface IExpansion {
    function plantHook() external returns (bytes memory);

    function harvestHook() external returns (bytes memory);

    struct ExpansionMetadata {
        uint256 urlParams;
    }

    function uriMetadata() external returns (ExpansionMetadata memory);
}
