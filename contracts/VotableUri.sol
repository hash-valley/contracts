//SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.0;

import "./interfaces/IWineBottle.sol";
import "./interfaces/IAddressStorage.sol";
import "./interfaces/IVinegar.sol";

contract VotableUri {
    uint256 public startTimestamp;
    mapping(uint256 => uint256) public voted;
    uint256 public forVotes;
    uint256 public againstVotes;
    string public newUri;
    address public artist;
    bool public settled = true;
    IAddressStorage addressStorage;

    mapping(uint256 => string) public imgVersions;
    uint256 public imgVersionCount = 0;
    mapping(uint256 => address) public artists;

    // EVENTS
    event Suggest(
        uint256 startTimestamp,
        string newUri,
        address artist,
        uint256 bottle,
        uint256 forVotes
    );
    event Support(uint256 startTimestamp, uint256 bottle, uint256 forVotes);
    event Retort(uint256 startTimestamp, uint256 bottle, uint256 againstVotes);
    event Complete(uint256 startTimestamp, string newUri, address artist);

    // CONSTRUCTOR
    constructor(address _addressStorage, string memory _imgUri) {
        addressStorage = IAddressStorage(_addressStorage);
        imgVersions[imgVersionCount] = _imgUri;
        artists[imgVersionCount] = msg.sender;
        imgVersionCount += 1;
    }

    // PUBLIC FUNCTIONS
    /// @notice suggest a new uri and royalties recipient
    /// @param _tokenId bottle token id to vote with
    /// @param _newUri new uri, preferably ipfs/arweave
    /// @param _artist secondary market royalties recipient
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
        IWineBottle bottle = IWineBottle(addressStorage.bottle());
        require(bottle.ownerOf(_tokenId) == msg.sender, "Bottle not owned");

        startTimestamp = block.timestamp;
        voted[_tokenId] = block.timestamp;
        forVotes = bottle.bottleAge(_tokenId);
        againstVotes = 0;
        newUri = _newUri;
        artist = _artist;
        settled = false;
        emit Suggest(startTimestamp, _newUri, _artist, _tokenId, forVotes);
    }

    /// @notice vote for the current suggestion
    /// @param _tokenId bottle to vote with
    function support(uint256 _tokenId) public {
        IWineBottle bottle = IWineBottle(addressStorage.bottle());
        require(bottle.ownerOf(_tokenId) == msg.sender, "Bottle not owned");
        require(voted[_tokenId] + 36 hours < block.timestamp, "Double vote");
        require(startTimestamp + 36 hours > block.timestamp, "No queue");

        voted[_tokenId] = block.timestamp;
        forVotes += bottle.bottleAge(_tokenId);
        emit Support(startTimestamp, _tokenId, forVotes);
    }

    /// @notice vote against current suggestion
    /// @param _tokenId bottle to vote with
    function retort(uint256 _tokenId) public {
        IWineBottle bottle = IWineBottle(addressStorage.bottle());
        require(bottle.ownerOf(_tokenId) == msg.sender, "Bottle not owned");
        require(voted[_tokenId] + 36 hours < block.timestamp, "Double vote");
        require(startTimestamp + 36 hours > block.timestamp, "No queue");

        voted[_tokenId] = block.timestamp;
        againstVotes += bottle.bottleAge(_tokenId);
        emit Retort(startTimestamp, _tokenId, againstVotes);
    }

    /// @notice writes suggested address and uri to contract mapping
    function complete() public {
        require(forVotes > againstVotes, "Blocked");
        require(startTimestamp + 36 hours < block.timestamp, "Too soon");
        require(startTimestamp + 48 hours > block.timestamp, "Too late");

        imgVersions[imgVersionCount] = newUri;
        artists[imgVersionCount] = artist;
        imgVersionCount += 1;
        settled = true;
        IVinegar(addressStorage.vinegar()).voteReward(artist);
        emit Complete(startTimestamp, newUri, artist);
    }
}
