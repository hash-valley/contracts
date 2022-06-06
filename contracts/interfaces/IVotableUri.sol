//SPDX-License-Identifier: Viral Public License
pragma solidity ^0.8.0;

interface IVotableUri {
    function artist() external view returns (address);

    function uri() external view returns (string memory);

    function image() external view returns (string memory);
}
