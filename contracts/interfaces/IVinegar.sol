// SPDX-License-Identifier: Viral Public License
pragma solidity ^0.8.0;

interface IVinegar {
    function voteReward(address recipient) external;

    function spoilReward(address recipient, uint256 cellarAge) external;

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    function rejuvenationCost(address account, uint256 cellarAge) external;
}
