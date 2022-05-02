//SPDX-License-Identifier: Unlicensed
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

import "../node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "../node_modules/@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IWineBottle.sol";
import "./UriUtils.sol";
import "./VotableUri.sol";

interface IGiveawayToken {
    function burnOne() external;
}

contract Vineyard is ERC721, Ownable, VotableUri {
    uint256 public totalSupply;
    uint256 public immutable firstSeasonLength = 3 weeks;
    uint256 public immutable seasonLength = 12 weeks;
    uint256 public immutable maxVineyards = 5500;
    uint256 public gameStart;

    mapping(uint256 => uint16[]) internal tokenAttributes;
    mapping(uint256 => uint256) public planted;
    mapping(uint256 => uint256) public watered;
    mapping(uint256 => uint256) public xp;
    mapping(uint256 => uint16) public streak;
    mapping(uint256 => uint256) public lastHarvested;

    string public baseUri;
    uint16 public immutable sellerFee = 750;

    uint16[3][15] internal mintReqs;

    // EVENTS
    event VineyardMinted(
        uint256 tokenId,
        uint256 location,
        uint256 elevation,
        uint256 elevationNegative,
        uint256 soilType
    );
    event Start(uint48 timestamp);
    event Planted(uint256 tokenId, uint256 season);
    event Harvested(uint256 tokenId, uint256 season, uint256 bottleId);

    // CONSTRUCTOR
    constructor(
        string memory _baseUri,
        string memory _imgUri,
        address _addressStorage,
        uint16[3][15] memory _mintReqs
    )
        ERC721("Hash Valley Vineyard", "VNYD")
        VotableUri(_addressStorage, _imgUri)
    {
        setBaseURI(_baseUri);
        addressStorage = IAddressStorage(_addressStorage);

        for (uint8 i = 0; i < _mintReqs.length; ++i) {
            mintReqs[i] = _mintReqs[i];
        }
    }

    /// @notice validates minting attributes
    function validateAttributes(uint16[] calldata _tokenAttributes)
        public
        view
        returns (bool)
    {
        require(_tokenAttributes.length == 4, "Incorrect number of params");
        require(_tokenAttributes[0] <= 14, "invalid 1st param");
        uint256 lower = mintReqs[_tokenAttributes[0]][0];
        uint256 upper = mintReqs[_tokenAttributes[0]][1];
        require(
            _tokenAttributes[1] >= lower && _tokenAttributes[1] <= upper,
            "Invalid 2nd param"
        );
        require(
            _tokenAttributes[2] == 0 || _tokenAttributes[2] == 1,
            "Invalid third attribute"
        );
        if (_tokenAttributes[2] == 1)
            require(mintReqs[_tokenAttributes[0]][2] == 1, "3rd cant be 1");
        require(_tokenAttributes[3] <= 5, "Invalid 4th param");
        return true;
    }

    // SALE
    /// @notice mints a new vineyard
    /// @param _tokenAttributes array of attribute ints [location, elevation, elevationIsNegative (0 or 1), soilType]
    function newVineyards(uint16[] calldata _tokenAttributes) public payable {
        // first 100 free
        if (totalSupply >= 100) {
            require(msg.value >= 0.05 ether, "Value below price");
        }

        _mintVineyard(_tokenAttributes);
    }

    /// @notice mints a new vineyard for free by burning a giveaway token
    function newVineyardGiveaway(uint16[] calldata _tokenAttributes) public {
        IGiveawayToken(addressStorage.giveawayToken()).burnOne();
        _mintVineyard(_tokenAttributes);
    }

    /// @notice internal vineyard minting function
    function _mintVineyard(uint16[] calldata _tokenAttributes) internal {
        uint256 tokenId = totalSupply;
        require(
            tokenId + 1 < maxVineyards,
            "Maximum number of vineyards have been minted"
        );

        validateAttributes(_tokenAttributes);

        _safeMint(msg.sender, tokenId);
        tokenAttributes[tokenId] = _tokenAttributes;
        totalSupply += 1;

        emit VineyardMinted(
            tokenId,
            _tokenAttributes[0],
            _tokenAttributes[1],
            _tokenAttributes[2],
            _tokenAttributes[3]
        );
    }

    /// @notice returns token attributes array
    function getTokenAttributes(uint256 _tokenId)
        public
        view
        returns (uint16[] memory attributes)
    {
        attributes = tokenAttributes[_tokenId];
    }

    // LOGISTICS
    /// @notice marks game as started triggering the first planting season to begin
    function start() public onlyOwner {
        require(gameStart == 0, "Game already started");
        gameStart = block.timestamp;
        emit Start(uint48(block.timestamp));
    }

    /// @notice withdraws sale proceeds
    function withdrawAll() public payable onlyOwner {
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
        require(harvestTime(), "Not harvest time");
        uint256 season = currSeason();
        require(planted[_tokenId] == season, "Vineyard already harvested");
        require(vineyardAlive(_tokenId), "Vineyard not alive");
        planted[_tokenId] = 0;

        if (lastHarvested[_tokenId] == season - 1) {
            streak[_tokenId] += 1;
        } else {
            streak[_tokenId] = 1;
        }
        lastHarvested[_tokenId] = season;
        xp[_tokenId] += 100 * streak[_tokenId];

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
        // TODO: some hooha with vineyard stats for time
        return 24 hours;
    }

    /// @notice window of time to water in
    function waterWindow(uint256 _tokenId) public view returns (uint256) {
        // TODO: some hooha with vineyard stats for time
        return 24 hours;
    }

    /// @notice checks if vineyard is alive (planted and watered)
    function vineyardAlive(uint256 _tokenId) public view returns (bool) {
        if (planted[_tokenId] == currSeason()) {
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

    // VIEWS
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

    /// @notice checks if its planting season
    function plantingTime() public view returns (bool) {
        if (gameStart == 0) return false;
        uint256 season = currSeason();
        uint256 plantingBegins;
        if (season == 1) plantingBegins = gameStart;
        else
            plantingBegins =
                gameStart +
                firstSeasonLength +
                (currSeason() - 2) *
                seasonLength;
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
        return vineMetadata(tokenId, imgVersionCount - 1);
    }

    /// @notice returns metadata string for current or historical versions
    function vineMetadata(uint256 _tokenId, uint256 _version)
        public
        view
        returns (string memory)
    {
        require(
            _exists(_tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );

        uint16[] memory attr = tokenAttributes[_tokenId];

        string memory json = string.concat(
            string.concat(
                '{"name": "Hash Valley Winery Vineyard ',
                UriUtils.uint2str(_tokenId),
                '", "external_url": "',
                baseUri,
                "/api/vine?version=",
                UriUtils.uint2str(_version),
                "&token=",
                UriUtils.uint2str(_tokenId),
                '", "description": "A vineyard...", "image": "'
            ),
            string.concat(
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
                UriUtils.uint2str(xp[_tokenId]),
                '", ',
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
