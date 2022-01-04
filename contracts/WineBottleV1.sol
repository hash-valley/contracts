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
    uint16 public immutable sellerFee = 850;

    event Rejuvenated(uint256 oldTokenId, uint256 newTokenId);

    // CONSTRUCTOR
    constructor(
        string memory _baseUri,
        string memory _imgUri,
        address _addressStorage
    ) ERC721("Hash Valley Vintage", "VNTG") {
        setBaseURI(_baseUri);
        imgVersions[imgVersionCount] = _imgUri;
        artists[imgVersionCount] = msg.sender;
        imgVersionCount += 1;
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

    function tokenURI(uint256 tokenId)
        public
        view
        override
        returns (string memory)
    {
        return bottleMetadata(tokenId, imgVersionCount - 1);
    }

    function bottleMetadata(uint256 _tokenId, uint256 _version)
        public
        view
        returns (string memory)
    {
        require(
            _exists(_tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );

        uint256 attr = attributes[_tokenId];
        string memory json = UriUtils.encodeBase64(
            bytes(
                string(
                    abi.encodePacked(
                        string(
                            abi.encodePacked(
                                '{"name": "Hash Valley Winery Bottle ',
                                UriUtils.uint2str(_tokenId),
                                '", "external_url": "',
                                baseUri,
                                "/api/bottle?version=",
                                UriUtils.uint2str(_version),
                                "&token=",
                                UriUtils.uint2str(_tokenId),
                                '", "description": "A wine bottle...", "image": "'
                            )
                        ),
                        string(
                            abi.encodePacked(
                                imgVersions[_version],
                                "?seed=",
                                UriUtils.uint2str(attr),
                                "-",
                                UriUtils.uint2str(bottleAge(_tokenId))
                            )
                        ),
                        string(
                            abi.encodePacked(
                                '"seller_fee_basis_points": ',
                                UriUtils.uint2str(sellerFee),
                                ", "
                            )
                        ),
                        string(
                            abi.encodePacked(
                                '"fee_recipient": "0x',
                                UriUtils.toAsciiString(artists[_version]),
                                '"'
                            )
                        ),
                        "}"
                    )
                )
            )
        );
        string memory output = string(
            abi.encodePacked("data:application/json;base64,", json)
        );

        return output;
    }

    // UPDATING
    uint256 startTimestamp;
    mapping(uint256 => uint256) voted;
    uint256 forVotes;
    uint256 againstVotes;
    string newUri;
    address artist;
    bool settled = true;

    event Suggest(
        uint256 startTimestamp,
        string newUri,
        address artist,
        uint256 bottle,
        uint256 forVotes
    );
    event Support(uint256 startTimestamp, uint256 bottle, uint256 forVotes);
    event Retort(uint256 startTimestamp, uint256 bottle, uint256 againstVotes);
    event Complete(uint256 startTimestamp);

    function suggest(
        uint256 _tokenId,
        string calldata _newUri,
        address _artist
    ) public {
        require(
            (forVotes == 0 && againstVotes == 0) ||
                (forVotes > againstVotes &&
                    startTimestamp + 9 days < block.timestamp) ||
                (forVotes > againstVotes &&
                    startTimestamp + 48 hours < block.timestamp &&
                    !settled) ||
                (againstVotes > forVotes &&
                    startTimestamp + 36 hours < block.timestamp),
            "Too soon"
        );
        require(ownerOf(_tokenId) == msg.sender, "Bottle not owned");

        startTimestamp = block.timestamp;
        voted[_tokenId] = block.timestamp;
        forVotes = bottleAge(_tokenId);
        againstVotes = 0;
        newUri = _newUri;
        artist = _artist;
        settled = false;
        emit Suggest(startTimestamp, _newUri, _artist, _tokenId, forVotes);
    }

    function support(uint256 _tokenId) public {
        require(ownerOf(_tokenId) == msg.sender, "Bottle not owned");
        require(voted[_tokenId] + 36 hours < block.timestamp, "Double vote");
        require(startTimestamp + 36 hours > block.timestamp, "No queue");

        voted[_tokenId] = block.timestamp;
        forVotes += bottleAge(_tokenId);
        emit Support(startTimestamp, _tokenId, forVotes);
    }

    function retort(uint256 _tokenId) public {
        require(ownerOf(_tokenId) == msg.sender, "Bottle not owned");
        require(voted[_tokenId] + 36 hours < block.timestamp, "Double vote");
        require(startTimestamp + 36 hours > block.timestamp, "No queue");

        voted[_tokenId] = block.timestamp;
        againstVotes += bottleAge(_tokenId);
        emit Retort(startTimestamp, _tokenId, againstVotes);
    }

    function complete() public {
        require(forVotes > againstVotes, "Blocked");
        require(startTimestamp + 36 hours < block.timestamp, "Too soon");
        require(startTimestamp + 48 hours > block.timestamp, "Too late");

        imgVersions[imgVersionCount] = newUri;
        artists[imgVersionCount] = artist;
        imgVersionCount += 1;
        settled = true;
        emit Complete(startTimestamp);
    }
}
