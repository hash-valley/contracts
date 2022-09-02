// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.12;

contract SaleParams {
    function getSalesPrice(uint256 supply) external pure returns (uint256) {
        if (supply < 1000) return 0 ether;
        return ((supply - 500) / 500) * .01 ether;
    }
}
