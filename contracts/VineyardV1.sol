//SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./UriUtils.sol";
import "./IAddressStorage.sol";

interface WineBottle {
    function newBottle(uint256 _vineyard) external returns (uint256);

    function ownerOf(uint256 tokenId) external view returns (address);

    function bottleAge(uint256 _tokenID) external view returns (uint256);
}

contract VineyardV1 is ERC721Enumerable, Ownable {
    uint256 public immutable firstSeasonLength = 3 weeks;
    uint256 public immutable seasonLength = 12 weeks;
    uint256 public immutable maxVineyards = 5500;
    uint256 public gameStart;
    IAddressStorage public addressStorage;

    mapping(uint256 => uint16[]) internal tokenAttributes;
    mapping(uint256 => uint256) public planted;
    mapping(uint256 => uint256) public watered;
    mapping(uint256 => uint256) public xp;
    mapping(uint256 => uint16) public streak;
    mapping(uint256 => uint256) public lastHarvested;

    string public baseUri;
    mapping(uint256 => string) public imgVersions;
    uint256 public imgVersionCount = 0;
    mapping(uint256 => address) public artists;
    uint16 public immutable sellerFee = 750;

    uint16[3][15] internal mintReqs;

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
        address _addressStorage
    ) ERC721("Hash Valley Vineyard", "VNYD") {
        setBaseURI(_baseUri);
        imgVersions[imgVersionCount] = _imgUri;
        artists[imgVersionCount] = msg.sender;
        imgVersionCount += 1;
        addressStorage = IAddressStorage(_addressStorage);
        mintReqs[0] = [21, 21, 1];
        mintReqs[1] = [131, 131, 0];
        mintReqs[2] = [20, 20, 0];
        mintReqs[3] = [240, 20310, 0];
        mintReqs[4] = [0, 12119, 0];
        mintReqs[5] = [1000, 10000, 0];
        mintReqs[6] = [0, 6684, 1];
        mintReqs[7] = [0, 15253, 0];
        mintReqs[8] = [29032, 29032, 0];
        mintReqs[9] = [0, 1200, 0];
        mintReqs[10] = [0, 455, 0];
        mintReqs[11] = [0, 13435, 0];
        mintReqs[12] = [0, 7080, 0];
        mintReqs[13] = [0, 120, 0];
        mintReqs[14] = [300, 2362, 0];
    }

    function validateAttributes(uint16[] calldata _tokenAttributes)
        public
        view
        returns (bool)
    {
        require(_tokenAttributes.length == 4, "Incorrect number of params");
        uint256 lower = mintReqs[_tokenAttributes[0]][0];
        uint256 upper = mintReqs[_tokenAttributes[0]][1];
        require(_tokenAttributes[0] <= 14, "invalid 1st param");
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
    }

    // SALE
    /// @notice mints a new vineyard
    /// @param _tokenAttributes array of attribute ints [location, elevation, elevationIsNegative (0 or 1), soilType]
    function newVineyards(uint16[] calldata _tokenAttributes) public payable {
        uint256 tokenId = totalSupply();
        validateAttributes(_tokenAttributes);
        require(
            tokenId + 1 < maxVineyards,
            "Maximum number of vineyards have been minted"
        );
        // first 100 free
        if (tokenId >= 100) {
            require(msg.value >= 50000000000000000, "Value below price");
        }

        _safeMint(msg.sender, tokenId);
        tokenAttributes[tokenId] = _tokenAttributes;
        emit VineyardMinted(
            tokenId,
            _tokenAttributes[0],
            _tokenAttributes[1],
            _tokenAttributes[2],
            _tokenAttributes[3]
        );
    }

    function getTokenAttributes(uint256 _tokenId)
        public
        view
        returns (uint16[] memory attributes)
    {
        attributes = tokenAttributes[_tokenId];
    }

    // LOGISTICS
    function start() public onlyOwner {
        require(gameStart == 0, "Game already started");
        gameStart = block.timestamp;
        emit Start(uint48(block.timestamp));
    }

    function withdrawAll() public payable onlyOwner {
        require(payable(_msgSender()).send(address(this).balance));
    }

    // GAME
    function currSeason() public view returns (uint256) {
        if (gameStart == 0) return 0;
        uint256 gameTime = block.timestamp - gameStart;
        if (gameTime <= firstSeasonLength) return 1;
        return (gameTime - firstSeasonLength) / seasonLength + 2;
    }

    function plant(uint256 _tokenId) public {
        require(plantingTime(), "Not planting time");
        uint256 season = currSeason();
        require(planted[_tokenId] != season, "Vineyard already planted");
        planted[_tokenId] = season;
        watered[_tokenId] = block.timestamp;
        emit Planted(_tokenId, planted[_tokenId]);
    }

    function plantMultiple(uint256[] calldata _tokenIds) public {
        for (uint8 i = 0; i < _tokenIds.length; i++) {
            plant(_tokenIds[i]);
        }
    }

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
        uint256 bottleId = WineBottle(wineBottle).newBottle(_tokenId);
        emit Harvested(_tokenId, season, bottleId);
    }

    function harvestMultiple(uint256[] calldata _tokenIds) public {
        for (uint8 i = 0; i < _tokenIds.length; i++) {
            harvest(_tokenIds[i]);
        }
    }

    function water(uint256 _tokenId) public {
        require(canWater(_tokenId), "Vineyard can't be watered");
        watered[_tokenId] = block.timestamp;
    }

    function waterMultiple(uint256[] calldata _tokenIds) public {
        for (uint8 i = 0; i < _tokenIds.length; i++) {
            water(_tokenIds[i]);
        }
    }

    function minWaterTime(uint256 _tokenId) public view returns (uint256) {
        // TODO: some hooha with vineyard stats for time
        return 24 hours;
    }

    function waterWindow(uint256 _tokenId) public view returns (uint256) {
        // TODO: some hooha with vineyard stats for time
        return 24 hours;
    }

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
    function currentStreak(uint256 _tokenId) public view returns (uint16) {
        uint256 season = currSeason();
        if (season == 0) return 0;
        if (lastHarvested[_tokenId] >= currSeason() - 1) {
            return streak[_tokenId];
        }
        return 0;
    }

    function canWater(uint256 _tokenId) public view returns (bool) {
        uint256 _canWater = watered[_tokenId] + minWaterTime(_tokenId);
        return
            _canWater <= block.timestamp &&
            _canWater + waterWindow(_tokenId) >= block.timestamp;
    }

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

    function canPlant(uint256 _tokenId) public view returns (bool) {
        return plantingTime() && planted[_tokenId] != currSeason();
    }

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

    function tokenURI(uint256 tokenId)
        public
        view
        override
        returns (string memory)
    {
        return vineMetadata(tokenId, imgVersionCount - 1);
    }

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
        string memory json = UriUtils.encodeBase64(
            bytes(
                string(
                    abi.encodePacked(
                        string(
                            abi.encodePacked(
                                '{"name": "Hash Valley Winery Vineyard ',
                                UriUtils.uint2str(_tokenId),
                                '", "external_url": "',
                                baseUri,
                                "/api/vine?version=",
                                UriUtils.uint2str(_version),
                                "&token=",
                                UriUtils.uint2str(_tokenId),
                                '", "description": "A vineyard...", "image": "'
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
                                UriUtils.uint2str(xp[_tokenId]),
                                '", '
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
        WineBottle _bottle = WineBottle(addressStorage.bottle());
        require(_bottle.ownerOf(_tokenId) == msg.sender, "Bottle not owned");

        startTimestamp = block.timestamp;
        voted[_tokenId] = block.timestamp;
        forVotes = _bottle.bottleAge(_tokenId);
        againstVotes = 0;
        newUri = _newUri;
        artist = _artist;
        settled = false;
        emit Suggest(startTimestamp, _newUri, _artist, _tokenId, forVotes);
    }

    function support(uint256 _tokenId) public {
        WineBottle _bottle = WineBottle(addressStorage.bottle());
        require(_bottle.ownerOf(_tokenId) == msg.sender, "Bottle not owned");
        require(voted[_tokenId] + 36 hours < block.timestamp, "Double vote");
        require(startTimestamp + 36 hours > block.timestamp, "No queue");

        voted[_tokenId] = block.timestamp;
        forVotes += _bottle.bottleAge(_tokenId);
        emit Support(startTimestamp, _tokenId, forVotes);
    }

    function retort(uint256 _tokenId) public {
        WineBottle _bottle = WineBottle(addressStorage.bottle());
        require(_bottle.ownerOf(_tokenId) == msg.sender, "Bottle not owned");
        require(voted[_tokenId] + 36 hours < block.timestamp, "Double vote");
        require(startTimestamp + 36 hours > block.timestamp, "No queue");

        voted[_tokenId] = block.timestamp;
        againstVotes += _bottle.bottleAge(_tokenId);
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
