// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

    import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

    //**** Interfaces ****//

    interface IRegistration{
        //NOTE: alternatively, enum can accessed through a getter function + importing the registration SC
        enum EntityType {RegulatoryAuthority, Miner, Refinery, Manufacturer, Distributor, Retailer}
        function getEntity(address) external returns(EntityType, bool);
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

    interface IManufacturing{
        function redeemBatteries(uint256 _LotCount, address _retailer) external;
    }

    interface IWasteManagement{
        function _disposeItem(address, address, uint256 , string memory) external;
    }

contract RetailingContract is ReentrancyGuard {


//This contract is used to ensure responsible sourcing in the initial stage

    //**** State Variable ****//
    IRegistration public Registration;
    IBatteries public Batteries;
    IBatteriesLOT public BatteriesLOT;
    IManufacturing public Manufacturing;
    IWasteManagement public WasteManagement;


    //**** Constructor ****//
    constructor(address _registration, address _batteriesSC, address _batteriesLOTSC, address _manufacturingSC, address _wastemgmt){
        Registration = IRegistration(_registration);
        Batteries = IBatteries(_batteriesSC);
        BatteriesLOT = IBatteriesLOT(_batteriesLOTSC);
        Manufacturing = IManufacturing(_manufacturingSC);
        WasteManagement = IWasteManagement(_wastemgmt);
    }

    //**** Modifiers ****//
    modifier onlyBatteriesSC{
         require(msg.sender == address(Batteries), "Only the batteries Lot smart contract can run this function");
        _;
    }

    modifier onlyBatteryLOTSmartContract{
         require(msg.sender == address(BatteriesLOT), "Only the batteries Lot smart contract can run this function");
        _;
    }

    modifier onlyRetailer{
        (IRegistration.EntityType entitytype, bool isRegistered) = Registration.getEntity(msg.sender);
        require(entitytype == IRegistration.EntityType.Retailer && isRegistered, "Only a retailer can execute this function");
        _;
    }


    //**** Events ****//
    event BatteriesRedeemed(address indexed redeemer, uint256 LotID);
    event BatteryDisposed(address indexed disposer, uint256 batteryID, bytes32 IPFShash);

    //**** Functions ****//
    function redeemBatteries(uint256 _LotCount) public nonReentrant{
        
        Manufacturing.redeemBatteries(_LotCount, msg.sender);
        emit BatteriesRedeemed(msg.sender, _LotCount);
    }

    function disposeBattery(uint256 batteryID,  string memory _IPFShash) public {
        require(msg.sender == Batteries.ownerOf(batteryID), "Only the current battery owner can execute this function");
        Batteries.transferFrom(msg.sender, address(WasteManagement), batteryID); //The WasteManagement SC must be approved first
        WasteManagement._disposeItem(msg.sender, address(Batteries), batteryID , _IPFShash);
        emit BatteryDisposed(msg.sender, batteryID, bytes32(bytes(_IPFShash)));
    }
}


//Note: after redeeming the batteries, the entity can either sell or consume based on their activities