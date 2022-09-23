// SPDX-License-Identifier: Viral Public License
/**
.___     .___ .______  ._______ ____   ____.______  .______  .______  
|   |___ : __|:      \ : .____/ \   \_/   /:      \ : __   \ :_ _   \ 
|   |   || : ||       || : _/\   \___ ___/ |   .   ||  \____||   |   |
|   :   ||   ||   |   ||   /  \    |   |   |   :   ||   :  \ | . |   |
 \      ||   ||___|   ||_.: __/    |___|   |___|   ||   |___\|. ____/ 
  \____/ |___|    |___|   :/                   |___||___|     :/      
                                                              :       
                                                                      
 */
pragma solidity ^0.8.12;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";
import "./interfaces/IWineBottle.sol";
import "./interfaces/IRoyaltyManager.sol";
import "./interfaces/IVotableUri.sol";
import "./interfaces/IAddressStorage.sol";
import "./libraries/UriUtils.sol";
import "./interfaces/IAlchemy.sol";
import "./interfaces/IGrape.sol";

// import "hardhat/console.sol";

interface IGiveawayToken {
    function burnOne() external;
}

interface ISaleParams {
    function getSalesPrice(uint256 supply) external pure returns (uint256);
}

contract Vineyard is ERC721, ERC2981 {
    IAddressStorage private addressStorage;
    address private saleParams;
    address public deployer;
    uint256 public totalSupply;
    uint256 public immutable firstSeasonLength = 3 weeks;
    uint256 public immutable seasonLength = 12 weeks;
    uint256 public immutable maxVineyards = 5500;
    uint256 public gameStart;

    mapping(address => uint8) private freeMints;

    /// @dev attributes are
    /// location, elevation, soil
    mapping(uint256 => int256[]) private tokenAttributes;
    mapping(uint256 => uint256) public planted;
    mapping(uint256 => uint256) public watered;
    mapping(uint256 => uint256) public xp;
    mapping(uint256 => uint16) public streak;
    mapping(uint256 => uint256) public lastHarvested;
    mapping(uint256 => uint256) public sprinkler;
    mapping(uint256 => uint256) public grapesHarvested;

    string public baseUri;
    uint16 public immutable sellerFee = 750;

    int256[2][18] private mintReqs;
    uint8[18] public climates;

    // EVENTS
    event VineyardMinted(
        uint256 tokenId,
        int256 location,
        int256 elevation,
        int256 soilType
    );
    event SprinklerPurchased(uint256 tokenId);
    event Start(uint48 timestamp);
    event Planted(uint256 tokenId, uint256 season);
    event Harvested(uint256 tokenId, uint256 season, uint256 bottleId);
    event HarvestFailure(uint256 tokenId, uint256 season);
    event GrapesHarvested(
        uint256 tokenId,
        uint256 season,
        uint256 harvested,
        uint256 remaining
    );

    // CONSTRUCTOR
    constructor(
        string memory _baseUri,
        address _addressStorage,
        int256[2][18] memory _mintReqs,
        uint8[18] memory _climates
    ) ERC721("Hash Valley Vineyard", "VNYD") {
        deployer = _msgSender();
        setBaseURI(_baseUri);
        addressStorage = IAddressStorage(_addressStorage);
        _setDefaultRoyalty(_msgSender(), 750);

        for (uint8 i = 0; i < _mintReqs.length; ++i) {
            mintReqs[i] = _mintReqs[i];
        }

        climates = _climates;
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

    /// @notice to manage sales params
    function setSaleParams(address _address) public {
        require(_msgSender() == deployer, "!deployer");
        saleParams = _address;
    }

    int256 private unlockedLocales = 15;

    /// @notice to manage sales params
    function unlockLocale() public {
        require(_msgSender() == deployer, "!deployer");
        unlockedLocales++;
    }

    /// @notice validates minting attributes
    function validateAttributes(
        int256[] calldata _tokenAttributes,
        bool giveaway
    ) public view returns (bool) {
        require(_tokenAttributes.length == 3, "wrong #params");
        if (giveaway) {
            require(_tokenAttributes[0] <= unlockedLocales, "inv 1st param");
        } else {
            require(_tokenAttributes[0] <= 14, "inv 1st param");
        }
        int256 lower = mintReqs[uint256(_tokenAttributes[0])][0];
        int256 upper = mintReqs[uint256(_tokenAttributes[0])][1];
        require(
            _tokenAttributes[1] >= lower && _tokenAttributes[1] <= upper,
            "inv 2nd param"
        );
        require(_tokenAttributes[2] <= 5, "inv 3rd param");
        return true;
    }

    // SALE
    /// @notice mints a new vineyard
    /// @param _tokenAttributes array of attribute ints [location, elevation, soilType]
    function newVineyards(int256[] calldata _tokenAttributes) public payable {
        uint256 price = ISaleParams(saleParams).getSalesPrice(totalSupply);
        require(msg.value >= price, "Value below price");
        if (price == 0) {
            require(freeMints[_msgSender()] < 5, "max free mints");
            freeMints[_msgSender()]++;
        }
        _mintVineyard(_tokenAttributes, false);
    }

    /// @notice mints a new vineyard for free by burning a giveaway token
    function newVineyardGiveaway(int256[] calldata _tokenAttributes) public {
        IGiveawayToken(addressStorage.giveawayToken()).burnOne();
        _mintVineyard(_tokenAttributes, true);
    }

    /// @notice private vineyard minting function
    function _mintVineyard(int256[] calldata _tokenAttributes, bool giveaway)
        private
    {
        uint256 tokenId = totalSupply;
        if (!giveaway) {
            require(tokenId < maxVineyards, "Max vineyards minted");
        }

        validateAttributes(_tokenAttributes, giveaway);

        _safeMint(_msgSender(), tokenId);
        tokenAttributes[tokenId] = _tokenAttributes;
        totalSupply += 1;

        emit VineyardMinted(
            tokenId,
            _tokenAttributes[0],
            _tokenAttributes[1],
            _tokenAttributes[2]
        );
    }

    /// @notice buys a sprinkler (lasts 3 years)
    function buySprinkler(uint256 _tokenId) public payable {
        require(
            sprinkler[_tokenId] + 156 weeks < block.timestamp,
            "already sprinkled"
        );
        require(msg.value >= 0.01 ether, "Value below price");
        sprinkler[_tokenId] = block.timestamp;

        emit SprinklerPurchased(_tokenId);
    }

    /// @notice returns token attributes array
    function getTokenAttributes(uint256 _tokenId)
        public
        view
        returns (int256[] memory attributes)
    {
        attributes = tokenAttributes[_tokenId];
    }

    /// @notice returns token climate
    function getClimate(uint256 _tokenId) public view returns (uint8) {
        return climates[uint256(tokenAttributes[_tokenId][0])];
    }

    // LOGISTICS
    /// @notice marks game as started triggering the first planting season to begin
    function start() public {
        require(_msgSender() == deployer, "!deployer");
        require(gameStart == 0, "Game already started");
        gameStart = block.timestamp;
        emit Start(uint48(block.timestamp));
    }

    /// @notice withdraws sale proceeds
    function withdrawAll() public payable {
        require(_msgSender() == deployer, "!deployer");
        require(payable(_msgSender()).send(address(this).balance));
    }

    // GAME
    /// @notice returns current season number
    function currSeason() public view returns (uint256) {
        if (gameStart == 0) return 0;
        uint256 gameTime = block.timestamp - gameStart;
        if (gameTime <= firstSeasonLength) return 1;
        return (gameTime - firstSeasonLength) / seasonLength + 2;
    }

    /// @notice plants the selected vineyard
    function plant(uint256 _tokenId) public {
        require(plantingTime(), "Not planting time");
        uint256 season = currSeason();
        require(planted[_tokenId] != season, "Vineyard already planted");
        planted[_tokenId] = season;
        watered[_tokenId] = block.timestamp;
        delete grapesHarvested[_tokenId];
        emit Planted(_tokenId, planted[_tokenId]);
    }

    /// @notice plant multiple vineyards in one tx
    function plantMultiple(uint256[] calldata _tokenIds) public {
        for (uint8 i = 0; i < _tokenIds.length; i++) {
            plant(_tokenIds[i]);
        }
    }

    /// @notice harvests the selected vineyard
    function harvest(uint256 _tokenId) public {
        require(ownerOf(_tokenId) == _msgSender(), "Not owner");
        require(harvestTime(), "Not harvest time");
        uint256 season = currSeason();
        require(planted[_tokenId] == season, "Vineyard already harvested");
        require(vineyardAlive(_tokenId), "Vineyard not alive");
        delete planted[_tokenId];

        // check for harvest failure (too many grapes harvested)
        if (
            random(string(abi.encodePacked(block.timestamp, _tokenId))) %
                100_00 <
            harvestFailureChance(grapesHarvested[_tokenId], maxGrapes(_tokenId))
        ) {
            emit HarvestFailure(_tokenId, season);
            return;
        }

        // xp
        if (lastHarvested[_tokenId] == season - 1) {
            streak[_tokenId] += 1;
        } else {
            streak[_tokenId] = 1;
        }
        lastHarvested[_tokenId] = season;
        if (IAlchemy(addressStorage.alchemy()).vitalized(_tokenId) == season) {
            xp[_tokenId] += 200 * streak[_tokenId]; // TODO: numbers
        } else {
            xp[_tokenId] += 100 * streak[_tokenId];
        }

        // mint bottle
        address wineBottle = addressStorage.bottle();
        uint256 bottleId = IWineBottle(wineBottle).newBottle(
            _tokenId,
            ownerOf(_tokenId)
        );
        emit Harvested(_tokenId, season, bottleId);
    }

    /// @notice harvest multiple vineyards in one tx
    function harvestMultiple(uint256[] calldata _tokenIds) public {
        for (uint8 i = 0; i < _tokenIds.length; i++) {
            harvest(_tokenIds[i]);
        }
    }

    /// @notice waters the selected vineyard
    function water(uint256 _tokenId) public {
        require(canWater(_tokenId), "Vineyard can't be watered");
        watered[_tokenId] = block.timestamp;
    }

    /// @notice water multiple vineyards in one tx
    function waterMultiple(uint256[] calldata _tokenIds) public {
        for (uint8 i = 0; i < _tokenIds.length; i++) {
            water(_tokenIds[i]);
        }
    }

    /// @notice min time before watering window opens
    function minWaterTime(uint256 _tokenId) public view returns (uint256) {
        uint256 sprinklerBreaks = sprinkler[_tokenId] + 156 weeks;
        if (sprinklerBreaks > block.timestamp) {
            return sprinklerBreaks - block.timestamp;
        }
        return 24 hours;
    }

    /// @notice window of time to water in
    function waterWindow(uint256 _tokenId) public view returns (uint256) {
        int256 location = tokenAttributes[_tokenId][0];
        if (location == 4 || location == 9 || location == 11) return 48 hours;
        return 24 hours;
    }

    /// @notice checks if vineyard is alive (planted and watered)
    function vineyardAlive(uint256 _tokenId) public view returns (bool) {
        uint256 _currSeason = currSeason();
        (uint256 deadline, uint256 season) = IAlchemy(addressStorage.alchemy())
            .withered(_tokenId);
        if (season == _currSeason && deadline < block.timestamp) {
            return false;
        }

        if (planted[_tokenId] == _currSeason) {
            if (
                block.timestamp <=
                watered[_tokenId] +
                    minWaterTime(_tokenId) +
                    waterWindow(_tokenId)
            ) {
                return true;
            }
            return false;
        }
        return false;
    }

    /// @notice harvest grapes
    function harvestGrapes(uint256 _tokenId) public {
        (uint256 seasonStart, uint256 _currSeason) = startOfSeason();

        require(ownerOf(_tokenId) == _msgSender(), "!owned");
        require(planted[_tokenId] == _currSeason, "!planted");
        require(_currSeason > 0, "!started");

        uint256 timePassed = block.timestamp - seasonStart;
        uint256 _maxGrapes = maxGrapes(_tokenId);
        uint256 _grapesHarvested = grapesHarvested[_tokenId];
        uint256 harvestable = (100_000 * (_maxGrapes * timePassed)) /
            (_currSeason == 1 ? firstSeasonLength : seasonLength) /
            100_000 -
            _grapesHarvested;

        grapesHarvested[_tokenId] += harvestable;
        IGrape(addressStorage.grape()).mint(harvestable);
        emit GrapesHarvested(
            _tokenId,
            _currSeason,
            harvestable,
            _maxGrapes - _grapesHarvested - harvestable
        );
    }

    // VIEWS
    /// @notice calculates chance that harvest fails
    function harvestFailureChance(uint256 _grapesHarvested, uint256 _maxGrapes)
        public
        pure
        returns (uint256)
    {
        uint256 thresh = (90_00 * _maxGrapes) / 100_00;
        if (_grapesHarvested >= thresh) {
            return 100_00; // 100% chance of failure
        } else {
            return (100_00 * _grapesHarvested) / _maxGrapes;
        }
    }

    /// @notice max grapes a vineyard can yield
    function maxGrapes(uint256 _tokenId) public view returns (uint256) {
        uint256 baseRate = 10_000;
        return xp[_tokenId] + baseRate; // TODO: numbers
    }

    /// @notice current harvest streak for vineyard
    function currentStreak(uint256 _tokenId) public view returns (uint16) {
        uint256 season = currSeason();
        if (season == 0) return 0;
        if (lastHarvested[_tokenId] >= currSeason() - 1) {
            return streak[_tokenId];
        }
        return 0;
    }

    /// @notice checks if vineyard can be watered
    function canWater(uint256 _tokenId) public view returns (bool) {
        uint256 _canWater = watered[_tokenId] + minWaterTime(_tokenId);
        return
            _canWater <= block.timestamp &&
            _canWater + waterWindow(_tokenId) >= block.timestamp;
    }

    /// @notice gets start time of current season
    function startOfSeason() public view returns (uint256, uint256) {
        uint256 season = currSeason();
        if (season == 1) {
            return (gameStart, season);
        } else {
            return (
                gameStart + firstSeasonLength + (season - 2) * seasonLength,
                season
            );
        }
    }

    /// @notice checks if its planting season
    function plantingTime() public view returns (bool) {
        if (gameStart == 0) return false;
        (uint256 plantingBegins, ) = startOfSeason();

        uint256 plantingEnds = plantingBegins + 1 weeks;
        return
            plantingEnds >= block.timestamp &&
            block.timestamp >= plantingBegins;
    }

    /// @notice checks if vineyard can be planted
    function canPlant(uint256 _tokenId) public view returns (bool) {
        return plantingTime() && planted[_tokenId] != currSeason();
    }

    /// @notice checks if it is harvesting season
    function harvestTime() public view returns (bool) {
        if (gameStart == 0) return false;
        uint256 season = currSeason();
        uint256 harvestEnds;
        if (season == 1) harvestEnds = gameStart + firstSeasonLength;
        else
            harvestEnds =
                gameStart +
                firstSeasonLength +
                (currSeason() - 1) *
                seasonLength;
        uint256 harvestBegins = harvestEnds - 1 weeks;
        return
            harvestEnds >= block.timestamp && block.timestamp >= harvestBegins;
    }

    /// @notice checks if vineyard can be harvested
    function canHarvest(uint256 _tokenId) public view returns (bool) {
        return
            harvestTime() &&
            planted[_tokenId] == currSeason() &&
            vineyardAlive(_tokenId);
    }

    /// @notice creates a random number
    function random(string memory input) internal pure returns (uint256) {
        return uint256(keccak256(abi.encodePacked(input)));
    }

    // URI
    /// @notice set a new base uri (backup measure)
    function setBaseURI(string memory _baseUri) public {
        require(_msgSender() == deployer, "!deployer");
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

        int256[] memory attr = tokenAttributes[_tokenId];

        string memory json = string.concat(
            string.concat(
                '{"name": "Hash Valley Winery Vineyard ',
                UriUtils.uint2str(_tokenId),
                '", "external_url": "',
                baseUri,
                "/vineyard/",
                UriUtils.uint2str(_tokenId),
                '", "image": "',
                IVotableUri(addressStorage.vineUri()).image(),
                "/",
                UriUtils.uint2str(uint256(attr[0])),
                '.png", "description": "Plant, tend and harvest this vineyard to grow your wine collection.", "animation_url": "'
            ),
            string.concat(
                IVotableUri(addressStorage.vineUri()).uri(),
                "?seed=",
                UriUtils.uint2str(uint256(attr[0])),
                "-",
                UriUtils.uint2str(uint256(attr[1] < 0 ? -attr[1] : attr[1])),
                "-",
                attr[1] < 0 ? "1" : "0",
                "-",
                UriUtils.uint2str(uint256(attr[2])),
                "-",
                UriUtils.uint2str(xp[_tokenId]),
                '", ',
                '"seller_fee_basis_points": ',
                UriUtils.uint2str(sellerFee),
                ', "fee_recipient": "0x',
                UriUtils.toAsciiString(
                    IVotableUri(addressStorage.vineUri()).artist()
                )
            ),
            string.concat(
                '", "attributes": [',
                string.concat(
                    '{"trait_type": "Location", "value": "',
                    locationNames[uint256(attr[0])],
                    '"},'
                ),
                string.concat(
                    '{"trait_type": "Elevation", "value": "',
                    attr[1] < 0 ? "-" : "",
                    UriUtils.uint2str(
                        uint256(attr[1] < 0 ? -attr[1] : attr[1])
                    ),
                    '"},'
                ),
                string.concat(
                    '{"trait_type": "Soil Type", "value": "',
                    soilNames[uint256(attr[2])],
                    '"},'
                ),
                string.concat(
                    '{"trait_type": "Xp", "value": "',
                    UriUtils.uint2str(xp[_tokenId]),
                    '"},'
                ),
                string.concat(
                    '{"trait_type": "Streak", "value": "',
                    UriUtils.uint2str(streak[_tokenId]),
                    '"},'
                ),
                string.concat(
                    '{"trait_type": "Sprinkler", "value": "',
                    sprinkler[_tokenId] + 156 weeks > block.timestamp
                        ? "true"
                        : "false",
                    '"}'
                ),
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

    string[18] private locationNames = [
        "Amsterdam",
        "Tokyo",
        "Napa Valley",
        "Denali",
        "Madeira",
        "Kashmere",
        "Outback",
        "Siberia",
        "Mt. Everest",
        "Amazon Basin",
        "Ohio",
        "Borneo",
        "Fujian Province",
        "Long Island",
        "Champagne",
        "Atlantis",
        "Orbital Ring",
        "Hypercubic Tesselation Plane"
    ];

    string[6] private soilNames = [
        "Rocky",
        "Sandy",
        "Clay",
        "Boggy",
        "Peaty",
        "Mulch"
    ];

    //ERC2981 stuff
    function setDefaultRoyalty(address _receiver, uint96 _feeNumerator) public {
        require(
            _msgSender() == addressStorage.royaltyManager(),
            "!RoyaltyManager"
        );
        _setDefaultRoyalty(_receiver, _feeNumerator);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC2981, ERC721)
        returns (bool)
    {
        return
            interfaceId == type(IERC2981).interfaceId ||
            super.supportsInterface(interfaceId);
    }
}
