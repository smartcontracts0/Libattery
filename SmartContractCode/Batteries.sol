// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol"; //Imported in case burning NFTs is used
import "@openzeppelin/contracts/access/Ownable.sol";

    //**** Interfaces ****//

    interface IManufacturing{
        function linkBatterytoRefinedMinerals(uint256, uint256) external;
    }
contract Batteries is ERC721URIStorage, Ownable{

    //**** State Variables ****//

    uint256 public tokenCount;
    IManufacturing public Manufacturing;

    constructor () ERC721("Batteries NFTs", "BTR"){
    } // The constructor uses the imported ERC721 contract which requires two inputs in its constructor, the name and symbol of the NFT
    
    //**** Modifiers ****//
     modifier onlyManufacturingSmartContract{
        require(msg.sender == address(Manufacturing), "Only the Manufacturing smart contract can run this function");
        _;
    }

    //**** Functions ****//
    function SetManufacturingSC(address _sc) external onlyOwner{
        Manufacturing = IManufacturing(_sc);
    }

    function mintBattery(string memory _tokenURI, uint256 _refinedmineralsID, address _manufacturer) external onlyManufacturingSmartContract returns(uint256, string memory){
        tokenCount++;
        _safeMint(_manufacturer, tokenCount); 
        _setTokenURI(tokenCount, _tokenURI);
        Manufacturing.linkBatterytoRefinedMinerals(tokenCount, _refinedmineralsID);
        return(tokenCount, _tokenURI);
    } 

}