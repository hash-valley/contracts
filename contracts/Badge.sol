// SPDX-License-Identifier: Viral Public License
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract Badge is ERC721 {
    uint8 private airdropped = 0;
    uint256 public currentTokenId;
    string private baseUri;

    constructor(string memory initBaseURI) ERC721("Hash Valley Early Supporter", "TY") {
        baseUri = initBaseURI;
    }

    function _baseURI() internal view override returns (string memory) {
        return baseUri;
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");

        string memory baseURI = _baseURI();
        return string(abi.encodePacked(baseURI, "/", Strings.toString(tokenId), ".json"));
    }

    /// @notice can be called once to compensate minters of original release
    function airdrop(address[] calldata recipients) public {
        require(airdropped == 0, "!");
        airdropped = 1;
        for (uint256 i = 0; i < recipients.length; i++) {
            _safeMint(recipients[i], currentTokenId);
            currentTokenId++;
        }
    }
}
