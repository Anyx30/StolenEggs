//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

contract NFT1 is ERC721Enumerable{

    uint tokenId;

    constructor() ERC721("NFT1","NFT1"){}

    function mint(uint amount) external{
        for(uint i=0;i<amount;i++){
            tokenId++;
            _safeMint(msg.sender,tokenId);
        }
    }
}