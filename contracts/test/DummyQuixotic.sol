//SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.0;

interface MockOwnable {
    function owner() external view returns (address);
}

contract DummyQuixotic {
    mapping(address => address) public payouts;
    mapping(address => uint256) public fee;

    function setRoyalty(
        address contractAddress,
        address payable _payoutAddress,
        uint256 _payoutPerMille
    ) external {
        require(
            msg.sender == MockOwnable(contractAddress).owner(),
            "not owner"
        );
        payouts[contractAddress] = _payoutAddress;
        fee[contractAddress] = _payoutPerMille;
    }
}
