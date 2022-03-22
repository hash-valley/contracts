//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "./IAddressStorage.sol";

interface IERC721 {
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    function burn(uint256 tokenId) external;
}

interface VinegarContract {
    function spoilReward(address recipient, uint256 amount) external;
}

interface WineBottle {
    function cellarAged(uint256 cellarTime) external view returns (uint256);
}

contract CellarV1 {
    IAddressStorage public addressStorage;

    mapping(uint256 => uint256) public staked;
    mapping(uint256 => uint256) public withdrawn;
    mapping(uint256 => address) public owner;

    //EVENTS
    event Staked(uint256 tokenId);
    event Withdrawn(uint256 tokenId, uint256 cellarTime);
    event Spoiled(uint256 tokenId);

    // FUNCTIONS
    constructor(address _addressStorage) {
        addressStorage = IAddressStorage(_addressStorage);
    }

    function cellarTime(uint256 _tokenID) public view returns (uint256) {
        if (withdrawn[_tokenID] == 0 && staked[_tokenID] != 0) {
            // currently in cellar
            return 0;
        }
        return withdrawn[_tokenID] - staked[_tokenID];
    }

    function stake(uint256 _tokenID) public {
        require(staked[_tokenID] == 0, "Id already staked");
        address wineBottle = addressStorage.bottle();
        staked[_tokenID] = block.timestamp;
        owner[_tokenID] = msg.sender;
        IERC721(wineBottle).safeTransferFrom(
            msg.sender,
            address(this),
            _tokenID
        );
        emit Staked(_tokenID);
    }

    function spoilChance(uint256 stakedDays)
        public
        pure
        returns (uint256 chance)
    {
        if (stakedDays < 360) {
            chance = 100 * (5 + ((365 - stakedDays) / 38)**2);
        } else {
            chance = 500;
        }
    }

    function withdraw(uint256 _tokenID) public {
        require(staked[_tokenID] != 0, "Id not staked");
        require(owner[_tokenID] == msg.sender, "Id not owned");

        address wineBottle = addressStorage.bottle();
        withdrawn[_tokenID] = block.timestamp;

        // probability of spoiling
        uint256 rand = random(
            string(abi.encodePacked(block.timestamp, _tokenID))
        ) % 10000; // TODO: better rand num?
        uint256 stakedDays = (withdrawn[_tokenID] - staked[_tokenID]) /
            (1 days);

        if (rand < spoilChance(stakedDays)) {
            IERC721(wineBottle).safeTransferFrom(
                address(this),
                msg.sender,
                _tokenID
            );
            emit Withdrawn(_tokenID, withdrawn[_tokenID] - staked[_tokenID]);
        } else {
            VinegarContract(addressStorage.vinegar()).spoilReward(
                msg.sender,
                WineBottle(addressStorage.bottle()).cellarAged(
                    cellarTime(_tokenID)
                ) * 1e18
            );
            IERC721(wineBottle).burn(_tokenID);
            emit Spoiled(_tokenID);
        }
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure returns (bytes4) {
        return
            bytes4(
                keccak256("onERC721Received(address,address,uint256,bytes)")
            );
    }

    function random(string memory input) internal pure returns (uint256) {
        return uint256(keccak256(abi.encodePacked(input)));
    }
}
