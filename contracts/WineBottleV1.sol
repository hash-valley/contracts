//SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "base64-sol/base64.sol";
import "./UriUtils.sol";
import "./IAddressStorage.sol";

interface CellarContract {
    function cellarTime(uint256 _tokenID) external view returns (uint256);
}

interface IVinegar {
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    function burn(address account, uint256 amount) external;
}

interface Vineyard {
    function getTokenAttributes(uint256 _tokenId)
        external
        view
        returns (uint16[] memory attributes);
}

contract WineBottleV1 is ERC721Enumerable, Ownable {
    IAddressStorage public addressStorage;

    uint256 public lastId = 0;
    mapping(uint256 => uint256) public bottleMinted;
    mapping(uint256 => uint256) public attributes;

    string public baseUri;
    mapping(uint256 => string) public imgVersions;
    uint256 public imgVersionCount = 0;
    mapping(uint256 => address) public artists;
    uint8 public immutable sellerFee = 250;

    event Rejuvenated(uint256 oldTokenId, uint256 newTokenId);

    // CONSTRUCTOR
    constructor(
        string memory _baseUri,
        string memory _imgUri,
        address _addressStorage
    ) ERC721("Hash Valley Vintage", "VNTG") {
        setBaseURI(_baseUri);
        updateImg(_imgUri, msg.sender);
        addressStorage = IAddressStorage(_addressStorage);
    }

    // PUBLIC FUNCTIONS
    function burn(uint256 tokenId) public {
        require(msg.sender == addressStorage.cellar(), "only cellar");
        _burn(tokenId);
    }

    function bottleAge(uint256 _tokenID) public view returns (uint256) {
        uint256 cellarTime = CellarContract(addressStorage.cellar()).cellarTime(
            _tokenID
        );
        // TODO: formula for finding how aged it gets
        uint256 cellarAged = cellarTime * cellarTime;

        return block.timestamp - bottleMinted[_tokenID] + cellarAged;
    }

    function newBottle(uint256 _vineyard) external returns (uint256) {
        address vineyard = addressStorage.vineyard();
        require(msg.sender == vineyard, "Can only be called by Vineyard");

        uint256 tokenID = totalSupply();
        bottleMinted[tokenID] = block.timestamp;
        // TODO: some hooha with vineyard id for attributes
        uint16[] memory vinParams = Vineyard(vineyard).getTokenAttributes(
            _vineyard
        );
        attributes[tokenID] = vinParams[0] + vinParams[1] + vinParams[3];
        _safeMint(tx.origin, tokenID);
        lastId = tokenID;
        return tokenID;
    }

    function rejuvenate(uint256 _oldTokenId) public returns (uint256) {
        require(attributes[_oldTokenId] != 0, "cannot rejuve");
        address cellar = addressStorage.cellar();
        uint256 cellarTime = CellarContract(cellar).cellarTime(_oldTokenId);
        IVinegar(addressStorage.vinegar()).burn(
            msg.sender,
            (3 * cellarTime) * 1e18
        );

        uint256 tokenId = lastId + 1;
        attributes[tokenId] = attributes[_oldTokenId];
        attributes[_oldTokenId] = 0;
        _safeMint(tx.origin, tokenId);
        lastId = tokenId;
        emit Rejuvenated(_oldTokenId, tokenId);
        return tokenId;
    }

    // URI
    function setBaseURI(string memory _baseUri) public onlyOwner {
        baseUri = _baseUri;
    }

    function updateImg(string memory imgUri, address artist) public onlyOwner {
        imgVersions[imgVersionCount] = imgUri;
        artists[imgVersionCount] = artist;
        imgVersionCount += 1;
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override
        returns (string memory)
    {
        return tokenURIHistorical(tokenId, imgVersionCount - 1);
    }

    function tokenURIHistorical(uint256 tokenId, uint256 version)
        public
        view
        returns (string memory)
    {
        require(
            _exists(tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );
        return
            string(
                abi.encodePacked(
                    baseUri,
                    "/?version=",
                    UriUtils.uint2str(version),
                    "&token=",
                    UriUtils.uint2str(tokenId)
                )
            );
    }
}
