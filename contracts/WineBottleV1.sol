//SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./IAddressStorage.sol";
import "./UriUtils.sol";
import "./VotableUri.sol";

interface ICellar {
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

interface IVineyard {
    function getTokenAttributes(uint256 _tokenId)
        external
        view
        returns (uint16[] memory attributes);
}

contract WineBottleV1 is ERC721, Ownable, VotableUri {
    IAddressStorage public addressStorage;

    uint256 public totalSupply;
    uint256 public lastId = 0;
    mapping(uint256 => uint256) public bottleMinted;
    mapping(uint256 => uint8[]) public attributes;

    string public baseUri;
    uint16 public immutable sellerFee = 750;

    uint256 internal wineClasses = 4;
    uint8[4] internal wineSubtypes = [3, 2, 2, 3];
    uint8[4][] internal wineNotes;
    uint8[][][] internal wineTypes;

    uint256 internal constant maxAge = 13000000000 * 365 days;
    uint256[] internal eraBounds;

    // EVENTS
    event Rejuvenated(uint256 oldTokenId, uint256 newTokenId);
    event BottleMinted(uint256 tokenId, uint8[] attributes);

    // CONSTRUCTOR
    constructor(
        string memory _baseUri,
        string memory _imgUri,
        address _addressStorage,
        uint256[] memory _eraBounds
    ) ERC721("Hash Valley Vintage", "VNTG") VotableUri(address(this), _imgUri) {
        setBaseURI(_baseUri);
        addressStorage = IAddressStorage(_addressStorage);
        eraBounds = _eraBounds;

        wineNotes.push([4, 4, 1]);
        wineNotes.push([5, 2]);
        wineNotes.push([2, 1]);
        wineNotes.push([4, 3, 2]);

        wineTypes.push(new uint8[][](3));
        wineTypes.push(new uint8[][](2));
        wineTypes.push(new uint8[][](2));
        wineTypes.push(new uint8[][](3));

        wineTypes[0].push(new uint8[](4));
        wineTypes[0][0].push(6);
        wineTypes[0][0].push(8);
        wineTypes[0][0].push(7);
        wineTypes[0][0].push(5);

        wineTypes[0].push(new uint8[](4));
        wineTypes[0][1].push(6);
        wineTypes[0][1].push(5);
        wineTypes[0][1].push(7);
        wineTypes[0][1].push(13);

        wineTypes[0].push(new uint8[](1));
        wineTypes[0][2].push(3);

        wineTypes[1].push(new uint8[](5));
        wineTypes[1][0].push(7);
        wineTypes[1][0].push(8);
        wineTypes[1][0].push(7);
        wineTypes[1][0].push(8);
        wineTypes[1][0].push(9);

        wineTypes[1].push(new uint8[](2));
        wineTypes[1][1].push(6);
        wineTypes[1][1].push(6);

        wineTypes[2].push(new uint8[](2));
        wineTypes[2][0].push(5);
        wineTypes[2][0].push(6);

        wineTypes[2].push(new uint8[](1));
        wineTypes[2][1].push(6);

        wineTypes[3].push(new uint8[](4));
        wineTypes[3][0].push(4);
        wineTypes[3][0].push(7);
        wineTypes[3][0].push(5);
        wineTypes[3][0].push(5);

        wineTypes[3].push(new uint8[](3));
        wineTypes[3][1].push(3);
        wineTypes[3][1].push(2);
        wineTypes[3][1].push(2);

        wineTypes[3].push(new uint8[](2));
        wineTypes[3][2].push(3);
        wineTypes[3][2].push(3);
    }

    // PUBLIC FUNCTIONS
    function burn(uint256 tokenId) public {
        require(msg.sender == addressStorage.cellar(), "only cellar");
        _burn(tokenId);
        totalSupply -= 1;
    }

    function cellarAged(uint256 cellarTime) public view returns (uint256) {
        if (cellarTime <= 360 days) {
            uint256 months = cellarTime / 30 days;
            uint256 monthTime = cellarTime - (months * 30 days);
            uint256 eraTime = eraBounds[months + 1] - eraBounds[months];
            uint256 monthFraction = (monthTime * eraTime) / (30 days);
            return eraBounds[months] + monthFraction;
        }
        return eraBounds[12];
    }

    function bottleAge(uint256 _tokenID) public view returns (uint256) {
        uint256 cellarTime = ICellar(addressStorage.cellar()).cellarTime(
            _tokenID
        );
        return
            block.timestamp - bottleMinted[_tokenID] + cellarAged(cellarTime);
    }

    function bottleEra(uint256 _tokenID) public view returns (string memory) {
        uint256 age = bottleAge(_tokenID);
        if (age < eraBounds[1]) return "Contemporary";
        else if (age < eraBounds[2]) return "Modern";
        else if (age < eraBounds[3]) return "Romantic";
        else if (age < eraBounds[4]) return "Renaissance";
        else if (age < eraBounds[5]) return "Medeival";
        else if (age < eraBounds[6]) return "Classical";
        else if (age < eraBounds[7]) return "Ancient";
        else if (age < eraBounds[8]) return "Neolithic";
        else if (age < eraBounds[9]) return "Prehistoric";
        else if (age < eraBounds[10]) return "Primordial";
        else if (age < eraBounds[11]) return "Archean";
        else if (age < eraBounds[12]) return "Astral";
        else return "Akashic";
    }

    function rejuvenate(uint256 _oldTokenId) public returns (uint256) {
        require(attributes[_oldTokenId].length > 0, "cannot rejuve");
        address cellar = addressStorage.cellar();
        uint256 cellarTime = ICellar(cellar).cellarTime(_oldTokenId);
        IVinegar(addressStorage.vinegar()).burn(
            msg.sender,
            (3 * cellarAged(cellarTime)) * 1e18
        );

        uint256 tokenId = lastId + 1;
        attributes[tokenId] = attributes[_oldTokenId];
        delete attributes[_oldTokenId];
        _safeMint(tx.origin, tokenId);
        lastId = tokenId;
        emit Rejuvenated(_oldTokenId, tokenId);
        return tokenId;
    }

    // MINTING FUNCTIONS

    function random(string memory input) internal pure returns (uint256) {
        return uint256(keccak256(abi.encodePacked(input)));
    }

    function newBottle(uint256 _vineyard, address _owner)
        external
        returns (uint256)
    {
        address vineyard = addressStorage.vineyard();
        require(msg.sender == vineyard, "Can only be called by Vineyard");

        uint256 tokenID = totalSupply;
        bottleMinted[tokenID] = block.timestamp;

        // TODO: some hooha with vineyard for attributes
        uint16[] memory vinParams = IVineyard(vineyard).getTokenAttributes(
            _vineyard
        );
        uint256 rand1 = random(
            string(abi.encodePacked(block.timestamp, tokenID))
        );
        uint256 rand2 = random(
            string(abi.encodePacked(block.timestamp + 1, tokenID))
        );
        uint256 rand3 = random(
            string(abi.encodePacked(block.timestamp + 2, tokenID))
        );
        uint256 rand4 = random(
            string(abi.encodePacked(block.timestamp + 3, tokenID))
        );
        uint256 bottleClass = rand1 % wineClasses;
        uint256 bottleSubtype = rand2 % wineSubtypes[bottleClass];
        uint256 bottleNote = rand3 % wineNotes[bottleClass][bottleSubtype];
        uint256 bottleType = rand4 %
            wineTypes[bottleClass][bottleSubtype][bottleNote];

        attributes[tokenID] = [
            uint8(bottleClass),
            uint8(bottleSubtype),
            uint8(bottleNote),
            uint8(bottleType)
        ];
        _safeMint(_owner, tokenID);
        lastId = tokenID;
        totalSupply += 1;

        emit BottleMinted(tokenID, attributes[tokenID]);
        return tokenID;
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

        uint8[] memory attr = attributes[_tokenId];
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
                                UriUtils.uint2str(attr[0]),
                                "-",
                                UriUtils.uint2str(attr[1]),
                                "-",
                                UriUtils.uint2str(attr[2]),
                                "-",
                                UriUtils.uint2str(attr[3]),
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
}
