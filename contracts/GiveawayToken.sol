//SPDX-License-Identifier: Viral Public License
pragma solidity ^0.8.0;

import "../node_modules/@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract GiveawayToken is ERC20 {
    constructor() ERC20("VineyardGiveaway", "VG") {
        _mint(msg.sender, 100e18);
    }

    /// @notice burns one token after it has been spent
    function burnOne() external {
        _burn(tx.origin, 1e18);
    }
}
