//SPDX-License-Identifier: Viral Public License
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
import "./Randomness.sol";
import "./interfaces/IVinegar.sol";
import "./interfaces/IRoyaltyManager.sol";
import "./interfaces/IVotableUri.sol";
import "./interfaces/IAddressStorage.sol";
import "./UriUtils.sol";

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

contract WineBottle is ERC721 {
    IAddressStorage private addressStorage;
    address public deployer;
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
        address _addressStorage,
        uint256[] memory _eraBounds
    ) ERC721("Hash Valley Vintage", "VNTG") {
        deployer = _msgSender();
        addressStorage = IAddressStorage(_addressStorage);
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

    // called once to init royalties
    bool private inited;

    function initR() external {
        require(!inited, "!init");
        IRoyaltyManager(addressStorage.royaltyManager()).updateRoyalties(
            _msgSender()
        );
        inited = true;
    }

    function owner() public view returns (address) {
        return addressStorage.royaltyManager();
    }

    // PUBLIC FUNCTIONS
    /// @notice burns a wine bottle token
    function burn(uint256 tokenId) public {
        require(_msgSender() == addressStorage.cellar(), "only cellar");
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
        IVinegar(addressStorage.vinegar()).rejuvenationCost(
            _msgSender(),
            cellarAged(cellarTime)
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
        require(_msgSender() == vineyard, "Only Vineyard");

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
    function setBaseURI(string memory _baseUri) public {
        require(
            _msgSender() == deployer || _msgSender() == owner(),
            "!deployer"
        );
        baseUri = _baseUri;
    }

    /// @notice returns metadata string for latest uri, royalty recipient settings
    function tokenURI(uint256 _tokenId)
        public
        view
        override
        returns (string memory)
    {
        require(
            _exists(_tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );

        uint8[] memory attr = attributes[_tokenId];
        string memory age = UriUtils.uint2str(bottleAge(_tokenId));
        string memory json = string.concat(
            string.concat(
                '{"name": "Hash Valley Wine Bottle ',
                UriUtils.uint2str(_tokenId),
                '", "external_url": "',
                baseUri,
                "/bottle/",
                UriUtils.uint2str(_tokenId),
                '", "image": "ipfs://QmU6e3sS9HJYmg9UV3h51h8WzhT1yrAMcNQnvWqWyLDhPM/',
                UriUtils.uint2str(attr[0]),
                '.png", "description": "A wine bottle...", "animation_url": "',
                IVotableUri(addressStorage.wineUri()).uri()
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
                age,
                '", "seller_fee_basis_points": ',
                UriUtils.uint2str(sellerFee),
                ', "fee_recipient": "0x',
                UriUtils.toAsciiString(IVotableUri(addressStorage.wineUri()).artist())
            ),
            string.concat(
                '", "attributes": [',
                string.concat(
                    '{"trait_type": "Type", "value": "',
                    typeNames[attr[0]],
                    '"},'
                ),
                string.concat(
                    '{"trait_type": "Subtype", "value": "',
                    getSubtype(attr[0], attr[1]),
                    '"},'
                ),
                string.concat(
                    '{"trait_type": "Note", "value": "',
                    getNote(attr[0], attr[1], attr[2]),
                    '"},'
                ),
                string.concat(
                    '{"trait_type": "Name", "value": "',
                    getName(attr[0], attr[1], attr[2], attr[3]),
                    '"},'
                ),
                string.concat(
                    '{"trait_type": "Era", "value": "',
                    bottleEra(_tokenId),
                    '"},'
                ),
                string.concat('{"trait_type": "Age", "value": "', age, '"}'),
                "]"
            ),
            "}"
        );

        string memory output = string.concat(
            "data:application/json;base64,",
            UriUtils.encodeBase64((bytes(json)))
        );

        return output;
    }

    string[4] typeNames = ["Red", "White", "Rose", "Sparkling"];

    string[10] subTypeNames = [
        "Fruity Dry Red",
        "Herbal Dry Red",
        "Sweet Red",
        "Dry White",
        "Sweet White",
        "Dry Rose",
        "Off Dry Rose",
        "White",
        "Red",
        "Rose"
    ];

    function getSubtype(uint256 _type, uint256 _subtype)
        public
        view
        returns (string memory)
    {
        uint256 offset;
        for (uint8 i; i < _type; i++) offset += wineSubtypes[i];
        return subTypeNames[offset + _subtype];
    }

    string[28] noteNames = [
        "Blueberry Blackberry",
        "Black Cherry Rasberry",
        "Strawberry Cherry",
        "Tart Cherry Cranberry",
        "Clay and Cured Meats",
        "Truffle & Forest",
        "Smoke Tobacco Leather",
        "Black Pepper Gravel",
        "Sweet Red",
        "Light Grapefruit Floral",
        "Light Citrus Lemon",
        "Light Herbal Grassy",
        "Rich Creamy Nutty",
        "Medium Perfume Floral",
        "Off-Dry Apricots Peaches",
        "Sweet Tropical Honey",
        "Herbal Savory",
        "Fruity Floral",
        "Off Dry Rose",
        "Dry Creamy Rich",
        "Dry Light Citrus",
        "Off Dry Floral",
        "Sweet Apricots Rich",
        "Dry Raspberry Blueberry",
        "Sweet Blueberry Cherry",
        "Off Dry Raspberry Cherry",
        "Dry Strawberry Floral",
        "Off Dry Strawberry Orange"
    ];

    function getNote(
        uint256 _type,
        uint256 _subtype,
        uint256 _note
    ) public view returns (string memory) {
        uint256 offset;
        for (uint8 i; i <= _type; i++) {
            for (uint8 j; j < wineNotes[i].length; j++) {
                if (i == _type && j == _subtype) {
                    return noteNames[offset + _note];
                } else {
                    offset += wineNotes[i][j];
                }
            }
        }
        return "";
    }

    string[162] nameNames = [
        "Shiraz",
        "Monastrell",
        "Mencia",
        "Nero Buono",
        "Petit Verdot",
        "Pinotage",
        "Cabernet Suavignon",
        "Merlot",
        "Super Tuscan",
        "Amarone",
        "Valpolicalla",
        "Cabernet France",
        "Sangiovese",
        "Priorat",
        "Garnacha",
        "Pinot Nior",
        "Carmenere",
        "Primitivo",
        "Counoise",
        "Barbera",
        "Grenache",
        "Zweigelt",
        "Gamay",
        "Blaufrankisch",
        "St. Laurent",
        "Spatburgunder",
        "Barolo",
        "Barbaresco",
        "Chianti",
        "Vacqueyras",
        "Gigondas",
        "Brunello di Montalcino",
        "Bourgogne",
        "Dolcetto",
        "Grignolino",
        "Barbera",
        "Beaujolais",
        "Taurasi",
        "Cahors",
        "Rioja",
        "Aglianico",
        "Graves",
        "Rioja",
        "Pessac-Leognan",
        "Cahors",
        "Medoc",
        "Sagrantino",
        "Tannat",
        "Pauillac",
        "Saint-Julien",
        "Chinon",
        "Lagrein",
        "Hermitage",
        "Bandol",
        "Cotes de Castillon",
        "Fronsac",
        "Rhone",
        "Recioto della Valpolicella",
        "Occhio di Pernice",
        "Freisa",
        "Cortese",
        "Vermentino",
        "Moschofilero",
        "Verdicchio",
        "Orvieto",
        "Pinot Blanc",
        "Greco di Tufo",
        "Chablis",
        "Picpoul",
        "Garganega",
        "Fiano",
        "Muscadet",
        "Assyrtiko",
        "Silvaner",
        "Albarino",
        "Pouilly Fume",
        "Entre-deux-Mers",
        "Ugni Blanc",
        "Touraine",
        "Sauvignon Blanc",
        "Chevemy",
        "Verdejo",
        "Chardonnay",
        "Montrachet",
        "Macconais",
        "Soave",
        "pessac-Leognan",
        "Savennieres",
        "Antao Vaz",
        "Cote de Beaune",
        "Torrontes",
        "Vouvray Sec",
        "Malvasiz Secco",
        "Condrieu",
        "Roussanne",
        "Tokaji",
        "Viognier",
        "Fiano",
        "Marsanne",
        "Chenin Blanc",
        "Spatlese",
        "Kaniett",
        "Demi-sec",
        "Gewurztraminer",
        "Muller-Thurgau",
        "Late Harvest",
        "Muscat Blanc",
        "Aboccato",
        "Sauternes",
        "Auslese",
        "Moelleux",
        "Loire Rose",
        "Bandol Rose",
        "Cabernet Franc Rose",
        "Syrah Rose",
        "Cabernet Sauvignon Rose",
        "Pinot Noir Rose",
        "Grenache Rose",
        "Provence Rose",
        "Sangiovese Rose",
        "Rosado",
        "Tavel",
        "Blush",
        "Merlot",
        "Zinfandel",
        "Vin Gris",
        "Garnacha Rosado",
        "Rose d' Anjou",
        "Vintage Champagne",
        "Blance de Noirs",
        "Blanc de Blancs",
        "Metodo Classico",
        "Brut Nature",
        "Sec",
        "Cava",
        "Brut",
        "Extra-Brut",
        "Metodo Classico",
        "Proseco Extra-Brut",
        "Champagne Extra Dry",
        "Proseco",
        "Sparkling Riesling",
        "Valdobbiadene",
        "Malvasia Secco",
        "Moscato d'Asti",
        "Vouvray Mousseux",
        "Demi-Sec",
        "Doux",
        "Asti Spumante",
        "Lambrusco Spumante",
        "Lambrusco Secco",
        "Sparkling Shiraz",
        "Brachetto d'Acqui",
        "Lambrusco Dolce",
        "Lambrusco Amabile",
        "Brachetto d'Acqui",
        "Champagne Rose",
        "Cremant Rose",
        "Cava Rose Brut",
        "Moscato Rose",
        "Brachetto d'Acqui Rose",
        "Cava Rose"
    ];

    function getName(
        uint256 _type,
        uint256 _subtype,
        uint256 _note,
        uint256 _name
    ) public view returns (string memory) {
        uint256 offset;
        for (uint8 i; i <= _type; i++) {
            for (uint8 j; j < wineTypes[i].length; j++) {
                for (uint8 k; k < wineTypes[i][j].length; k++) {
                    if (i == _type && j == _subtype && k == _note) {
                        return nameNames[offset + _name];
                    } else {
                        offset += wineTypes[i][j][k];
                    }
                }
            }
        }
        return "";
    }
}
