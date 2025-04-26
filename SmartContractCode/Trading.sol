// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

    import "@openzeppelin/contracts/token/ERC721/IERC721.sol"; 
    import "@openzeppelin/contracts/security/ReentrancyGuard.sol";


    //**** Interfaces ****//

    interface IRegistration{

        //NOTE: alternatively, enum can accessed through a getter function + importing the registration SC
        enum EntityType {RegulatoryAuthority, Miner, Refinery, Manufacturer, Distributor, Retailer}
        function getEntity(address) external returns(EntityType, bool);
    }
    
        
    interface IRefinedMinerals{
        function mintRefinedMaterialPackage(address) external returns(uint256);
        function transferFrom(address from, address to, uint256 tokenId) external;
    }

    interface IBatteries{
        function mintBattery(string memory, uint256, address) external returns(uint256, string memory);
        function transferFrom(address from, address to, uint256 tokenId) external;
        function ownerOf(uint256 tokenId) external view returns (address owner);
    }

    interface IBatteriesLOT{
        function mintLOT(string memory, uint256[5] memory, address) external returns(uint256, string memory);
        function transferFrom(address from, address to, uint256 tokenId) external;
    }


//This contract facilitates the trading at all stages of the supply chain
contract TradingContract is ReentrancyGuard{

    //**** State Variable ****//
    IERC721 public batteriesSC;
    IERC721 public lotSC;
    IRefinedMinerals public RefinedMinerals;
    IRegistration public Registration;
    IBatteries public Batteries;
    IBatteriesLOT public BatteriesLOT;
    uint256 public refinedMineralsCount;
    uint256 public batteryLotCount;
    uint256 public batteryCount;

    struct refinedMineralNFT{
        uint256 itemId;
        //address itemSC;
        uint256 tokenID;
        uint256 price;
        address payable seller;
        bool sold;
    }

    struct batteryLotNFT{
        uint256 itemId;
        //address itemSC;
        uint256 tokenID;
        uint256 price;
        address payable seller;
        bool sold;        
    }

    struct batteryNFT{
        uint256 itemId;
        //address itemSC;
        uint256 tokenID;
        uint256 price;
        address payable seller;
        bool sold;        
    }

    mapping(uint256 => refinedMineralNFT) public refinedMineralNFTs;
    mapping(uint256 => batteryLotNFT) public batteryLotNFTs;
    mapping(uint256 => batteryNFT) public batteryNFTs;


   //**** Constructor ****//
   constructor(address _registration, address _refinedmineralSC, address _batteriesSC, address _batteriesLOTSC){
        Registration = IRegistration(_registration);
        RefinedMinerals = IRefinedMinerals(_refinedmineralSC);
        Batteries = IBatteries(_batteriesSC);
        BatteriesLOT = IBatteriesLOT(_batteriesLOTSC);
   }

   //**** Modifiers ****//
    modifier onlyRegulatoryAuthority{
        (IRegistration.EntityType entitytype, bool isRegistered) = Registration.getEntity(msg.sender);
        require(entitytype == IRegistration.EntityType.RegulatoryAuthority && isRegistered, "Only the regulatory authority can run this function");
        _;
    }

    modifier onlyRefinery{
        (IRegistration.EntityType entitytype, bool isRegistered) = Registration.getEntity(msg.sender);
        require(entitytype == IRegistration.EntityType.Refinery && isRegistered, "Only the refinery can execute this function");
        _;
    }

    modifier onlyBatteriesSC{
         require(msg.sender == address(Batteries), "Only the batteries Lot smart contract can run this function");
        _;
    }

    modifier onlyBatteryLOTSmartContract{
         require(msg.sender == address(BatteriesLOT), "Only the batteries Lot smart contract can run this function");
        _;
    }

    modifier onlyManufacturer{
        (IRegistration.EntityType entitytype, bool isRegistered) = Registration.getEntity(msg.sender);
        require(entitytype == IRegistration.EntityType.Manufacturer && isRegistered, "Only the manufacturer can execute this function");
        _;
    }

    modifier onlyRetailer{
        (IRegistration.EntityType entitytype, bool isRegistered) = Registration.getEntity(msg.sender);
        require(entitytype == IRegistration.EntityType.Retailer && isRegistered, "Only a retailer can execute this function");
        _;
    }

   //**** Events ****//
    event RefinedMineralNFTListed(uint256 itemID, uint256 tokenID, uint256 price, address indexed seller);
    event RefinedMineralNFTPurchased(uint256 itemID, uint256 tokenID, uint256 price, address indexed seller, address indexed buyer); 
    event BatteryLotNFTListed(uint256 itemID, uint256 tokenID, uint256 price, address indexed seller);
    event BatteryLotNFTPurchased(uint256 itemID, uint256 tokenID, uint256 price, address indexed seller, address indexed buyer); 
    event BatteryNFTListed(uint256 itemID, uint256 tokenID, uint256 price, address indexed seller);
    event BatteryNFTPurchased(uint256 itemID, uint256 tokenID, uint256 price, address indexed seller, address indexed buyer); 

   //**** Functions ****// 

   //This function lists the refined minerals package NFT
   function listRefinedMineralsPackage(uint256 _tokenId, uint256 _price) external payable onlyRefinery nonReentrant{

        require(_price > 0, "Price must be greater than zero");
        refinedMineralsCount++;
        RefinedMinerals.transferFrom(msg.sender, address(this), _tokenId); //The Trading SC must be approved first
        refinedMineralNFTs[refinedMineralsCount]= refinedMineralNFT(refinedMineralsCount, _tokenId, _price  * 1 ether, payable(msg.sender), false);
        emit RefinedMineralNFTListed(refinedMineralsCount, _tokenId, _price  * 1 ether, msg.sender);

   } 

   //A function to delist the listed NFT can be added, but it is not needed for the testing

   //
   function purchaseRefinedMineralsPackage(uint256 _itemId) external payable onlyManufacturer nonReentrant{
        refinedMineralNFT storage RMNFT = refinedMineralNFTs[_itemId];
        require(_itemId > 0 && _itemId <= refinedMineralsCount, "The requested refined minerals NFT does not exist" );
        require(msg.value == RMNFT.price);
        require(!RMNFT.sold, "The requested refined mineral NFT has already been sold");
        require(msg.sender != RMNFT.seller, "The listed NFT cannot be purchased by its owner");

        RefinedMinerals.transferFrom(address(this), msg.sender, RMNFT.tokenID);
        //payable(address(this)).call{value: RMNFT.price};
        payable(RMNFT.seller).transfer(RMNFT.price); //The value of the NFT is transferred directly to the seller
        RMNFT.sold = true;
        emit RefinedMineralNFTPurchased(RMNFT.itemId, RMNFT.tokenID, RMNFT.price, RMNFT.seller, msg.sender); 
   }

   function listBatteryLot(uint256 _tokenId, uint256 _price) external payable onlyManufacturer nonReentrant{
        require(_price > 0, "Price must be greater than zero");
        batteryLotCount++;
        BatteriesLOT.transferFrom(msg.sender, address(this), _tokenId); //The Trading SC must be approved first
        batteryLotNFTs[batteryLotCount]= batteryLotNFT(batteryLotCount, _tokenId, _price  * 1 ether , payable(msg.sender), false);
        emit BatteryLotNFTListed(batteryLotCount, _tokenId, _price  * 1 ether , msg.sender);
   }

   function purchaseBatteryLot(uint256 _itemId) external payable onlyRetailer nonReentrant{
        batteryLotNFT storage BLOTNFT = batteryLotNFTs[_itemId];
        require(_itemId > 0 && _itemId <= batteryLotCount, "The requested Battery Lot NFT does not exist" );
        require(msg.value == BLOTNFT.price);
        require(!BLOTNFT.sold, "The requested Battery Lot NFT has already been sold");
        require(msg.sender != BLOTNFT.seller, "The listed NFT cannot be purchased by its owner");

        //payable(address(this)).call{value: BLOTNFT.price};
        payable(BLOTNFT.seller).transfer(BLOTNFT.price);
        BatteriesLOT.transferFrom(address(this), msg.sender, BLOTNFT.tokenID);
        BLOTNFT.sold = true;
        emit BatteryLotNFTPurchased(BLOTNFT.itemId, BLOTNFT.tokenID, BLOTNFT.price, BLOTNFT.seller, msg.sender); 
   }

    function listBattery(uint256 _tokenId, uint256 _price) external payable onlyRetailer nonReentrant{
        require(_price > 0, "Price must be greater than zero");
        batteryCount++;
        Batteries.transferFrom(msg.sender, address(this), _tokenId); //The Trading SC must be approved first
        batteryNFTs[batteryLotCount]= batteryNFT(batteryCount, _tokenId, _price  * 1 ether , payable(msg.sender), false);
        emit BatteryNFTListed(batteryCount, _tokenId, _price  * 1 ether, msg.sender);
   }

    function purchaseBattery(uint256 _itemId) external payable nonReentrant{
        batteryNFT storage BNFT = batteryNFTs[_itemId];
        require(_itemId > 0 && _itemId <= batteryCount, "The requested Battery NFT does not exist" );
        require(msg.value == BNFT.price);
        require(!BNFT.sold, "The requested Battery NFT has already been sold");
        require(msg.sender != BNFT.seller, "The listed NFT cannot be purchased by its owner");

        //payable(address(this)).call{value: BNFT.price};
        payable(BNFT.seller).transfer(BNFT.price);
        Batteries.transferFrom(address(this), msg.sender, BNFT.tokenID);
        BNFT.sold = true;
        emit BatteryNFTPurchased(BNFT.itemId, BNFT.tokenID, BNFT.price, BNFT.seller, msg.sender); 
   }


}