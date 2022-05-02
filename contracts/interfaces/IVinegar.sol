//SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.0;

interface IVinegar {
    function voteReward(address recipient) external;

    function spoilReward(address recipient, uint256 amount) external;

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    function burn(address account, uint256 amount) external;
}
