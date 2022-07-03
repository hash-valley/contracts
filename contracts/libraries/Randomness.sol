//SPDX-License-Identifier: MIT License
pragma solidity ^0.8.0;

library Randomness {
    /// @notice creates a random number
    function random(string memory input) internal pure returns (uint256) {
        return uint256(keccak256(abi.encodePacked(input)));
    }

    /// @notice makes a weighted random selection from an array
    /// @param r1 first element for rand num
    /// @param r2 second element for rand num
    /// @param numOptions length of array to select from
    /// @param weightingElement attribute to affect weights
    /// @return uint256 index from 0 - numOptions
    function weightedRandomSelection(
        uint256 r1,
        uint256 r2,
        uint256 numOptions,
        uint256 weightingElement
    ) internal pure returns (uint256) {
        uint256 sumOfWeights = 0;
        uint256[] memory weights = new uint256[](numOptions);
        for (uint256 i = 0; i < numOptions; ++i) {
            uint256 w = 1 + (i * weightingElement);
            sumOfWeights += w;
            weights[i] = w;
        }

        uint256 rand = random(string(abi.encodePacked(r1, r2))) % sumOfWeights;
        for (uint256 i = 0; i < numOptions; ++i) {
            if (rand < weights[i]) {
                return i;
            }
            rand -= weights[i];
        }
        // execution should never reach here
        return 0;
    }
}
