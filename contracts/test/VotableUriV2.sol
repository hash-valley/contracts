// SPDX-License-Identifier: Viral Public License
pragma solidity ^0.8.0;

import "../interfaces/IWineBottle.sol";
import "../interfaces/IAddressStorage.sol";
import "../interfaces/IVinegar.sol";
import "../interfaces/IRoyaltyManager.sol";
import "hardhat/console.sol";

contract VotableUriV2 {
    IAddressStorage addressStorage;
    address zeroAddress = address(0);

    uint32 settled;

    mapping(uint256 => string) public imgVersions;
    uint256 public imgVersionCount = 0;
    mapping(uint256 => address) public artists;
    address[] public proposalList;

    struct Proposal {
        address artist;
        uint32 createdAt;
        uint256 bottle;
        string uri;
        int256 votes;
    }
    mapping(address => Proposal) public proposals;

    // track used bottles
    mapping(uint256 => address) public forVotes;
    mapping(uint256 => address) public againstVotes;

    // EVENTS
    event Suggest(Proposal proposal);
    event Support(address proposer, uint256 bottle, int256 votes);
    event Retort(address proposer, uint256 bottle, int256 votes);
    event Update(address proposer, int256 votes);
    event Complete(address proposer, string newUri, address artist);

    // CONSTRUCTOR
    constructor(address _addressStorage, string memory _imgUri) {
        addressStorage = IAddressStorage(_addressStorage);
        imgVersions[imgVersionCount] = _imgUri;
        artists[imgVersionCount] = msg.sender;
        imgVersionCount += 1;

        settled = uint32(block.timestamp);
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
        IWineBottle bottle = IWineBottle(addressStorage.bottle());
        require(bottle.ownerOf(_tokenId) == msg.sender, "Bottle not owned");
        require(proposals[msg.sender].createdAt == 0, "already exists");
        uint256 age = bottle.bottleAge(_tokenId);

        removeVotes(_tokenId, age);
        forVotes[_tokenId] = msg.sender;

        Proposal memory newProposal = Proposal(
            _artist,
            uint32(block.timestamp),
            _tokenId,
            _newUri,
            int256(age)
        );
        proposals[msg.sender] = newProposal;
        proposalList.push(msg.sender);

        emit Suggest(newProposal);
    }

    function updateProposal(string calldata _newUri, address _artist) public {
        Proposal memory p = proposals[msg.sender];
        require(p.createdAt > 0, "!exist");
        p.uri = _newUri;
        p.artist = _artist;
    }

    /// @notice vote for the current suggestion
    /// @param _tokenId bottle to vote with
    function support(uint256 _tokenId, address _proposer) public {
        IWineBottle bottle = IWineBottle(addressStorage.bottle());
        require(bottle.ownerOf(_tokenId) == msg.sender, "Bottle not owned");

        Proposal memory p = proposals[_proposer];
        uint256 age = bottle.bottleAge(_tokenId);
        removeVotes(_tokenId, age);
        p.votes += int256(age);
        forVotes[_tokenId] = _proposer;

        emit Support(_proposer, _tokenId, p.votes);
    }

    /// @notice vote against current suggestion
    /// @param _tokenId bottle to vote with
    function retort(uint256 _tokenId, address _proposer) public {
        IWineBottle bottle = IWineBottle(addressStorage.bottle());
        require(bottle.ownerOf(_tokenId) == msg.sender, "Bottle not owned");

        Proposal memory p = proposals[_proposer];
        uint256 age = bottle.bottleAge(_tokenId);
        removeVotes(_tokenId, age);
        p.votes -= int256(age);
        againstVotes[_tokenId] = _proposer;

        emit Retort(_proposer, _tokenId, p.votes);
    }

    /// @notice writes suggested address and uri to contract mapping
    function complete(address _proposer) public {
        require(block.timestamp > settled + 7 days, "too soon");
        require(isActive(_proposer), "!active");
        require(isHighest(_proposer), "!highest");

        Proposal memory p = proposals[_proposer];
        imgVersions[imgVersionCount] = p.uri;
        artists[imgVersionCount] = p.artist;
        imgVersionCount += 1;
        settled = uint32(block.timestamp);

        IVinegar(addressStorage.vinegar()).voteReward(p.artist);
        IRoyaltyManager(addressStorage.royaltyManager()).updateRoyalties(
            p.artist
        );

        emit Complete(_proposer, p.uri, p.artist);
    }

    function isActive(address _proposer) public view returns (bool) {
        if (proposalList.length <= 21) return true;
        // TODO: something tricky here
        return false;
    }

    function isHighest(address _proposer) public view returns (bool) {
        int256 votes = proposals[_proposer].votes;
        uint loops = 21 < proposalList.length ? 21 : proposalList.length;
        for (uint i; i < loops; ++i) {
            address a = proposalList[i]; // TODO: select index here
            if (a != _proposer) {
                if (proposals[a].votes >= votes) {
                    return false;
                }
            }
        }
        return true;
    }

    function removeVotes(uint256 _tokenId, uint256 _age) private {
        if (forVotes[_tokenId] != zeroAddress) {
            proposals[forVotes[_tokenId]].votes -= int256(_age);
            emit Update(
                forVotes[_tokenId],
                proposals[forVotes[_tokenId]].votes
            );
            delete forVotes[_tokenId];
        } else if (againstVotes[_tokenId] != zeroAddress) {
            proposals[againstVotes[_tokenId]].votes += int256(_age);
            emit Update(
                againstVotes[_tokenId],
                proposals[againstVotes[_tokenId]].votes
            );
            delete againstVotes[_tokenId];
        }
    }

    // // TODO: only for dev, remove later
    // function fakes(uint160 start) public {
    //     for (uint160 i; i < 100; ++i) {
    //         address a = address(start + i);
    //         Proposal memory newProposal = Proposal(
    //             a,
    //             uint32(block.timestamp),
    //             80,
    //             "ipfs",
    //             8
    //         );
    //         proposals[a] = newProposal;
    //         proposalList.push(a);
    //     }
    // }
}
