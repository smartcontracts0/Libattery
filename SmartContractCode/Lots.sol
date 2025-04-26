// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol"; //Imported in case burning NFTs is used
import "@openzeppelin/contracts/access/Ownable.sol";

    interface IManufacturing{
        function linkBatteriestoLot(uint256, uint256[5] memory) external;
    }

contract Lots is ERC721URIStorage, Ownable{
    uint256 public tokenCount;
    address public ManufacturingSC;
    IManufacturing public Manufacturing;
    constructor () ERC721("Battery Lot NFTs", "BTRLOT"){
    } // The constructor uses the imported ERC721 contract which requires two inputs in its constructor, the name and symbol of the NFT
    

    modifier onlyManufacturingSmartContract{
        require(msg.sender == address(Manufacturing), "Only the Manufacturing smart contract can run this function");
        _;
    }

    function SetManufacturingSC(address _sc) external onlyOwner{
        Manufacturing = IManufacturing(_sc);
    }

    function mintLOT(string memory _tokenURI, uint256[5] memory _childIDs, address _LotCreator) external onlyManufacturingSmartContract returns(uint256, string memory){
        tokenCount++;
        _safeMint(_LotCreator, tokenCount); 
        _setTokenURI(tokenCount, _tokenURI);
        Manufacturing.linkBatteriestoLot(tokenCount, _childIDs);
        return(tokenCount, _tokenURI);
    } 

}