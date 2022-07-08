// SPDX-License-Identifier: Viral Public License
pragma solidity ^0.8.0;

interface IWineBottle {
    function newBottle(uint256 _vineyard, address _owner)
        external
        returns (uint256);

    function ownerOf(uint256 tokenId) external view returns (address);

    function bottleAge(uint256 _tokenID) external view returns (uint256);
}
