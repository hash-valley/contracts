// SPDX-License-Identifier: Viral Public License
/**
.___     .___ .______  ._______._____  .______  .______  
|   |___ : __|:      \ : .____/:_ ___\ :      \ : __   \ 
|   |   || : ||       || : _/\ |   |___|   .   ||  \____|
|   :   ||   ||   |   ||   /  \|   /  ||   :   ||   :  \ 
 \      ||   ||___|   ||_.: __/|. __  ||___|   ||   |___\
  \____/ |___|    |___|   :/    :/ |. |    |___||___|    
                                :   :/                   
                                    :                    

 */
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./interfaces/IAddressStorage.sol";

contract Vinegar is ERC20 {
    IAddressStorage public addressStorage;

    constructor(address _addressStorage) ERC20("Vinegar", "VNG") {
        addressStorage = IAddressStorage(_addressStorage);
    }

    /// @notice mints tokens to recipient address of vote
    function voteReward(address recipient) external {
        require(
            _msgSender() == addressStorage.wineUri() ||
                _msgSender() == addressStorage.vineUri(),
            "invalid caller"
        );
        _mint(recipient, 500e18);
    }

    /// @notice mints tokens to recipient who spoiled their bottle
    function spoilReward(address recipient, uint256 cellarAge) external {
        require(_msgSender() == addressStorage.cellar(), "not cellar");
        _mint(recipient, ageToVinegar(cellarAge));
    }

    /// @notice burns the specified amount of tokens
    function rejuvenationCost(address account, uint256 cellarAge) external {
        require(_msgSender() == addressStorage.bottle(), "Not Bottle");
        _burn(account, 3 * ageToVinegar(cellarAge));
    }

    /// @notice burns tokens for withering
    function witherCost(uint256 amount) external {
        require(_msgSender() == addressStorage.alchemy(), "Not Bottle");
        _burn(tx.origin, amount);
    }

    /// @notice conversion from seconds in cellar to vinegar tokens (wei)
    function ageToVinegar(uint256 cellarAge) internal pure returns (uint256) {
        return (cellarAge * 1e18) / 1 days;
    }
}
