//SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.0;

interface IAddressStorage {
    function cellar() external view returns (address);

    function vinegar() external view returns (address);

    function vineyard() external view returns (address);

    function bottle() external view returns (address);

    function giveawayToken() external view returns (address);

    function royaltyManager() external view returns (address);
}
