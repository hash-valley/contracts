// SPDX-License-Identifier: Viral Public License
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract GiveawayToken is ERC20 {
    constructor() ERC20("Wine Merchant", "WM") {
        _mint(msg.sender, 150 * 10**decimals());
    }

    /// @notice burns one token after it has been spent
    function burnOne() external {
        _burn(tx.origin, 1 * 10**decimals());
    }

    uint8 private airdropped = 0;

    /// @notice can be called once to compensate minters of original release
    function airdrop(address[] calldata recipients, uint256[] calldata values)
        public
    {
        require(airdropped == 0, "!");
        airdropped = 1;
        for (uint256 i = 0; i < recipients.length; i++) {
            _mint(recipients[i], values[i] * 1e18);
        }
    }
}
