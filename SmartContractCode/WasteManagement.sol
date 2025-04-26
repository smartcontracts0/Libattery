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
    }





contract WasteManagementContract {


//This contract is used to ensure responsible sourcing in the initial stage

    //**** State Variable ****//
    IRegistration public Registration;
    IRefinedMinerals public RefinedMinerals;
    IBatteries public Batteries;
    IBatteriesLOT public BatteriesLOT;

    struct DisposedItemDetails{
        uint256 tokenID;
        address itemSC; //The smart contract address of the disposed item
        address payable owner;
        bytes32 IPFShash;
        bool disposed;
    }

    //Disposer => (battery ID => Details)
    mapping(address => mapping(uint256 => DisposedItemDetails)) public DisposedItem;

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
    //**** Events ****//
    event ItemDisposed(address disposer, address itemSC, uint256 itemID, bytes32 IPFShash);        

    //**** Functions ****//

    function _disposeItem(address caller, address _itemSC, uint256 _itemID, string memory _IPFShash) external {
        
        DisposedItem[caller][_itemID] = DisposedItemDetails(_itemID, _itemSC, payable(caller), bytes32(bytes(_IPFShash)), true);
        emit ItemDisposed(caller, _itemSC, _itemID, bytes32(bytes(_IPFShash)));        
    }

    //Function1: Dispose unused/old batteries, details should be provided


    






}
