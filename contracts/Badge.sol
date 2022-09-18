// SPDX-License-Identifier: Viral Public License
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract Badge is ERC721 {
    uint8 private airdropped = 0;
    uint256 public currentTokenId;

    constructor(string memory _baseURI)
        public
        ERC721Full("Hash Valley Early Supporter", "TY")
    {
        setBaseURI(_baseURI);
    }

    /// @notice can be called once to compensate minters of original release
    function airdrop(address[] calldata recipients) public {
        require(airdropped == 0, "!");
        airdropped = 1;
        for (uint256 i = 0; i < recipients.length; i++) {
            _safeMint(recipient, currentTokenId);
            currentTokenId++;
        }
    }
}
