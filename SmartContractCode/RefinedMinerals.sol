// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol"; //Imported in case burning NFTs is used
import "@openzeppelin/contracts/access/Ownable.sol";


contract RefinedMaterial is ERC721, Ownable{
    
    struct NFTAttributes{
        uint256 refindMineralQuantity;
    }
    
    mapping(uint256 => NFTAttributes) public tokenAttributes;
    uint256 public tokenCount;
    address public miningSC;
    address public manufacturingSC;
    constructor () ERC721("Refined Material NFTs", "RM"){
    } // The constructor uses the imported ERC721 contract which requires two inputs in its constructor, the name and symbol of the NFT
    
    //Modifiers
    modifier onlyMiningSmartContract{
        require(msg.sender == miningSC, "Only the mining smart contract can run this function");
        _;
    }

    function setMiningSC(address _sc) external onlyOwner{
        miningSC = _sc;
    }

    function setManufacturingSC(address _sc) external onlyOwner{
        manufacturingSC = _sc;
    }

    function mintRefinedMaterialPackage(address _owner) external onlyMiningSmartContract returns(uint256){
        tokenCount++;
        tokenAttributes[tokenCount].refindMineralQuantity = 10;
        _safeMint(_owner, tokenCount); 
        //_setTokenURI(tokenCount, _tokenURI);
        return(tokenCount);
    }

    function getQuantity(uint256 tokenId) external view returns (uint256) {
        require(_exists(tokenId), "Token does not exist");
        return tokenAttributes[tokenId].refindMineralQuantity;
    }

    function updateTokenAttributes(uint256 tokenId) external {
        require(_exists(tokenId), "Token does not exist");
        require(msg.sender == manufacturingSC || msg.sender == miningSC, "Only authorized smart contracts are allowed to update the attributes");
        tokenAttributes[tokenId].refindMineralQuantity -= 2;
    }
}