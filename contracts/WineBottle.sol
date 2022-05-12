//SPDX-License-Identifier: Unlicensed
/**
         ___ .___ .______  ._______     ._______ ._______  _____.______._.___    ._______
.___    |   |: __|:      \ : .____/     : __   / : .___  \ \__ _:|\__ _:||   |   : .____/
:   | /\|   || : ||       || : _/\      |  |>  \ | :   |  |  |  :|  |  :||   |   | : _/\ 
|   |/  :   ||   ||   |   ||   /  \     |  |>   \|     :  |  |   |  |   ||   |/\ |   /  \
|   /       ||   ||___|   ||_.: __/     |_______/ \_. ___/   |   |  |   ||   /  \|_.: __/
|______/|___||___|    |___|   :/                    :/       |___|  |___||______/   :/   
        :                                           :                                    
        :                                                                                

 */
pragma solidity ^0.8.12;

import "../node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "../node_modules/@openzeppelin/contracts/access/Ownable.sol";
import "./UriUtils.sol";
import "./Randomness.sol";
import "./VotableUri.sol";
import "./interfaces/IVinegar.sol";

interface ICellar {
    function cellarTime(uint256 _tokenID) external view returns (uint256);
}

interface IVineyard {
    function getTokenAttributes(uint256 _tokenId)
        external
        view
        returns (uint16[] memory attributes);

    function getClimate(uint256 _tokenId) external view returns (uint8);
}

contract WineBottle is ERC721, Ownable, VotableUri {
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
    )
        ERC721("Hash Valley Vintage", "VNTG")
        VotableUri(_addressStorage, _imgUri)
    {
        setBaseURI(_baseUri);
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
    /// @notice burns a wine bottle token
    function burn(uint256 tokenId) public {
        require(msg.sender == addressStorage.cellar(), "only cellar");
        _burn(tokenId);
        totalSupply -= 1;
    }

    /// @notice gets surplus age generated from cellar based on real time in cellar
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

    /// @notice calculates total age of bottle based on real time and cellar time
    function bottleAge(uint256 _tokenID) public view returns (uint256) {
        uint256 cellarTime = ICellar(addressStorage.cellar()).cellarTime(
            _tokenID
        );
        return
            block.timestamp - bottleMinted[_tokenID] + cellarAged(cellarTime);
    }

    /// @notice gets era of bottle based on age
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

    /// @notice revives a spoiled bottle
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
    /// @notice mints a new bottle with generated attributes
    function newBottle(uint256 _vineyard, address _owner)
        external
        returns (uint256)
    {
        address vineyard = addressStorage.vineyard();
        require(msg.sender == vineyard, "Can only be called by Vineyard");

        uint256 tokenID = totalSupply;
        bottleMinted[tokenID] = block.timestamp;

        uint16[] memory vinParams = IVineyard(vineyard).getTokenAttributes(
            _vineyard
        );

        uint256 bottleClass = Randomness.weightedRandomSelection(
            block.timestamp,
            tokenID,
            wineClasses,
            vinParams[1]
        );
        uint256 bottleSubtype = Randomness.weightedRandomSelection(
            block.timestamp + 1,
            tokenID,
            wineSubtypes[bottleClass],
            vinParams[3]
        );
        uint256 bottleNote = Randomness.weightedRandomSelection(
            block.timestamp + 2,
            tokenID,
            wineNotes[bottleClass][bottleSubtype],
            IVineyard(vineyard).getClimate(_vineyard)
        );
        uint256 bottleType = Randomness.weightedRandomSelection(
            block.timestamp + 3,
            tokenID,
            wineTypes[bottleClass][bottleSubtype][bottleNote],
            0
        );

        // adjust for champagne
        if (bottleClass == 3 && vinParams[0] != 14) {
            if (
                (bottleSubtype == 0 && bottleNote == 0 && bottleType == 0) ||
                (bottleSubtype == 0 && bottleNote == 2 && bottleType == 0) ||
                (bottleSubtype == 2 && bottleNote == 0 && bottleType == 0)
            ) {
                bottleType++;
            }
        }

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

    /// @notice returns metadata string for latest uri, royalty recipient settings
    function tokenURI(uint256 tokenId)
        public
        view
        override
        returns (string memory)
    {
        return bottleMetadata(tokenId, imgVersionCount - 1);
    }

    /// @notice returns metadata string for current or historical versions
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

        string memory json = string.concat(
            string.concat(
                '{"name": "Hash Valley Winery Bottle ',
                UriUtils.uint2str(_tokenId),
                '", "external_url": "',
                baseUri,
                "/api/bottle?version=",
                UriUtils.uint2str(_version),
                "&token=",
                UriUtils.uint2str(_tokenId),
                '", "description": "A wine bottle...", "image": "',
                imgVersions[_version]
            ),
            string.concat(
                "?seed=",
                UriUtils.uint2str(attr[0]),
                "-",
                UriUtils.uint2str(attr[1]),
                "-",
                UriUtils.uint2str(attr[2]),
                "-",
                UriUtils.uint2str(attr[3]),
                "-",
                UriUtils.uint2str(bottleAge(_tokenId)),
                '"seller_fee_basis_points": ',
                UriUtils.uint2str(sellerFee),
                ', "fee_recipient": "0x',
                UriUtils.toAsciiString(artists[_version]),
                '"}'
            )
        );

        string memory output = string.concat(
            "data:application/json;base64,",
            UriUtils.encodeBase64((bytes(json)))
        );

        return output;
    }
}
