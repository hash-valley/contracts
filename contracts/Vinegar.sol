//SPDX-License-Identifier: Unlicensed
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

import "../node_modules/@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./interfaces/IAddressStorage.sol";

contract Vinegar is ERC20 {
    IAddressStorage public addressStorage;

    constructor(address _addressStorage) ERC20("Vinegar", "VNG") {
        addressStorage = IAddressStorage(_addressStorage);
    }

    /// @notice mints tokens to recipient address of vote
    function voteReward(address recipient) external {
        require(
            msg.sender == addressStorage.bottle() ||
                msg.sender == addressStorage.vineyard(),
            "invalid caller"
        );
        _mint(recipient, 3 weeks * 1e18);
    }

    /// @notice mints tokens to recipient who spoiled their bottle
    function spoilReward(address recipient, uint256 amount) external {
        require(msg.sender == addressStorage.cellar(), "not cellar");
        _mint(recipient, amount * 1e18);
    }

    /// @notice burns the specified amount of tokens
    function burn(address account, uint256 amount) external {
        require(msg.sender == addressStorage.bottle(), "Not Bottle");
        _burn(account, amount);
    }
}
