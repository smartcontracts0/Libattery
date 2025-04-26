// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

    //**** Interfaces ****//

    interface IRegistration{

        //NOTE: alternatively, enum can accessed through a getter function + importing the registration SC
        enum EntityType {RegulatoryAuthority, Miner, Refinery, Manufacturer, Distributor, Retailer}
        function getEntity(address) external returns(EntityType, bool);
    }

    interface IRefinedMinerals{
        function mintRefinedMaterialPackage(address) external returns(uint256);
        function transferFrom(address from, address to, uint256 tokenId) external;
        function ownerOf(uint256 tokenId) external view returns (address owner);
        function updateTokenAttributes(uint256 tokenId) external;
        function getQuantity(uint256 tokenId) external view returns (uint256);
    }

    interface IBatteries{
        function mintBattery(string memory, uint256, address) external returns(uint256, string memory);
        function transferFrom(address from, address to, uint256 tokenId) external;
        function ownerOf(uint256 tokenId) external view returns (address owner);
    }

    interface IBatteriesLOT{
        function mintLOT(string memory, uint256[5] memory, address) external returns(uint256, string memory);
        function transferFrom(address from, address to, uint256 tokenId) external;
        function ownerOf(uint256 tokenId) external view returns (address owner);

    }
    
    interface IWasteManagement{
        function _disposeItem(address, address, uint256 , string memory) external;
    }

contract ManufacturingContract {


//This contract is used to ensure responsible sourcing in the initial stage

    //**** State Variable ****//
    IRegistration public Registration;
    IRefinedMinerals public RefinedMinerals;
    IBatteries public Batteries;
    IBatteriesLOT public BatteriesLOT;
    IWasteManagement public WasteManagement;
    mapping(uint256 => uint256) public linkBatteriestoRefinedMinerals;
    mapping(uint256 => uint256[5]) public linkBatterytoLot;
    uint256 public batteriesCount; //A counter for batteries
    uint256 public batteriesLotCount; //A counter for battery lots


    struct BatteryDetails{
        uint256 batteryCount;
        uint256 batteryID;
        address batterySC;
        address payable creator;
    }

    struct LotDetails{
        uint256 LotCount; //This is the number within the Management SC
        uint256 LotID; //This is the ID within the NFT smart contract
        address LotSC; 
        //uint256 price;
        address payable creator;
    }   
    mapping(uint256 => BatteryDetails) public batteriesMapping;
    mapping(uint256 => LotDetails) public batteriesLotMapping;



    //**** Constructor ****//
    constructor(address _registration, address _refinedmineralSC, address _batteriesSC, address _batteriesLOTSC, address _wastemgmt){
        Registration = IRegistration(_registration);
        RefinedMinerals = IRefinedMinerals(_refinedmineralSC);
        Batteries = IBatteries(_batteriesSC);
        BatteriesLOT = IBatteriesLOT(_batteriesLOTSC);
        WasteManagement = IWasteManagement(_wastemgmt);

    }


    //**** Modifiers ****//
    modifier onlyBatteriesSC{
         require(msg.sender == address(Batteries), "Only the batteries smart contract can run this function");
        _;
    }

    modifier onlyBatteryLOTSmartContract{
         require(msg.sender == address(BatteriesLOT), "Only the batteries Lot smart contract can run this function");
        _;
    }

    modifier onlyManufacturer{
        (IRegistration.EntityType entitytype, bool isRegistered) = Registration.getEntity(msg.sender);
        require(entitytype == IRegistration.EntityType.Manufacturer && isRegistered, "Only manufacturers can execute this function");
        _;
    }



    //**** Events ****//
    event BatteryManufactured(address indexed owner, uint256 tokenID, string tokenURI);
    event BatteryLotCreated (address indexed owner, uint256 tokenID, string tokenURI);


    //**** Functions ****//

    function linkBatterytoRefinedMinerals(uint256 _batteryID, uint256 _refinedMineralsID) external onlyBatteriesSC{
            linkBatteriestoRefinedMinerals[_batteryID] = _refinedMineralsID;
    }

    function linkBatteriestoLot (uint256 _LotID, uint256[5] memory _BatteriesIDs) external onlyBatteryLOTSmartContract{
        for(uint256 i = 0; i < _BatteriesIDs.length; i++ ){
            linkBatterytoLot[_LotID][i] = _BatteriesIDs[i];
        }
    }

    
    function manufactureBatteries(uint256 _refinedMineralsID, string memory _tokenURI) external onlyManufacturer{
        require(RefinedMinerals.ownerOf(_refinedMineralsID) == msg.sender,"The refined minerals NFT ID does not belong to the caller");
        require(RefinedMinerals.getQuantity(_refinedMineralsID) >= 2, "The remaining quantity is insufficient to create a Battery");
        //RefinedMinerals.transferFrom(msg.sender, address(this), _refinedMineralsID);
        batteriesCount++;
        batteriesMapping[batteriesCount] = BatteryDetails(batteriesCount, _refinedMineralsID, address(Batteries), payable(msg.sender));
        (uint256 tokenID, string memory tokenURI) = Batteries.mintBattery(_tokenURI, _refinedMineralsID , msg.sender);
        RefinedMinerals.updateTokenAttributes(_refinedMineralsID);

        emit BatteryManufactured(msg.sender, tokenID, tokenURI);
    }

    function createBatteryLot(uint256[5] memory _tokenIDs, string memory _tokenURI) external onlyManufacturer{
        for(uint256 i = 0; i < _tokenIDs.length; i++){
            require(Batteries.ownerOf(_tokenIDs[i]) == msg.sender,"The token ID does not belong to the caller");
        }
        
        for(uint256 i = 0; i < _tokenIDs.length; i++){
            Batteries.transferFrom(msg.sender, address(this), _tokenIDs[i]);
            //batteriesCount++;
            //batteriesMapping[batteriesCount] = BatteryDetails(batteriesCount, _tokenIDs[i], address(Batteries), payable(msg.sender));
        }

        batteriesLotCount++;
        (uint256 tokenID, string memory tokenURI) = BatteriesLOT.mintLOT(_tokenURI, _tokenIDs, msg.sender);
        batteriesLotMapping[batteriesLotCount] = LotDetails(batteriesLotCount, tokenID, address(BatteriesLOT), payable(msg.sender));

        emit BatteryLotCreated (msg.sender, tokenID, tokenURI);
    }

    function redeemBatteries(uint256 _LotCount, address _retailer) external {
        LotDetails storage BLot = batteriesLotMapping[_LotCount];
        require(_retailer == BatteriesLOT.ownerOf(_LotCount), "Only the current owner of the LOT can execute this function");
        BatteriesLOT.transferFrom(_retailer, address(this), BLot.LotID); //The Lot NFT is transferred back to the SC
        for(uint256 i = 0; i < linkBatterytoLot[BLot.LotID].length; i++ ){
            Batteries.transferFrom(address(this), _retailer, linkBatterytoLot[BLot.LotID][i]);
        }
    }

    function disposeBattery(uint256 batteryID,  string memory _IPFShash) public {
        require(msg.sender == Batteries.ownerOf(batteryID), "Only the current battery owner can execute this function");
        Batteries.transferFrom(msg.sender, address(WasteManagement), batteryID); //The WasteManagement SC must be approved first
        WasteManagement._disposeItem(msg.sender, address(Batteries), batteryID , _IPFShash);
    }

    function disposeBatteryLot(uint256 batteryLotID,  string memory _IPFShash) public {
        require(msg.sender == BatteriesLOT.ownerOf(batteryLotID), "Only the current battery owner can execute this function");
        BatteriesLOT.transferFrom(msg.sender, address(WasteManagement), batteryLotID); //The WasteManagement SC must be approved first
        WasteManagement._disposeItem(msg.sender, address(BatteriesLOT), batteryLotID , _IPFShash);
    }

}
