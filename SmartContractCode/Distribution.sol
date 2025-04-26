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
    }

    interface IBatteriesLOT{
        function mintLOT(string memory, uint256[5] memory, address) external returns(uint256, string memory);
        function transferFrom(address from, address to, uint256 tokenId) external;
        function ownerOf(uint256 tokenId) external view returns (address owner);
    }

    interface IWasteManagement{
        function _disposeItem(address, address, uint256 , string memory) external;
    }

contract DistributionContract {


//This contract is used to ensure responsible sourcing in the initial stage

    //**** State Variable ****//
    IRegistration public Registration;
    IBatteriesLOT public BatteriesLOT;
    IWasteManagement public WasteManagement;
    IRefinedMinerals public RefinedMinerals;
    enum batteryLotState{Pending, EnRoute, Delivered}
    enum refinedMineralsState{Pending, EnRoute, Delivered}

    struct Signature{
        address receiver;
        address SC;
        uint tokenId;
        string message;
        bytes sig;
    }

    //itemID => Signature
    mapping(uint => Signature) public rmSignatures;
    mapping(uint => Signature) public bLotSignatures;


    //refinedminerals ID => State
    mapping(uint256 => refinedMineralsState) public rMState;
    //Battery Lot ID => State
    mapping(uint256 => batteryLotState) public bLotState;

    //**** Constructor ****//
    constructor(address _registration, address _batteriesLOTSC, address _refinedmineralSC, address _wastemgmt){
        Registration = IRegistration(_registration);
        RefinedMinerals = IRefinedMinerals(_refinedmineralSC);
        BatteriesLOT = IBatteriesLOT(_batteriesLOTSC);
        WasteManagement = IWasteManagement(_wastemgmt);
    }

    //**** Modifiers ****//

    modifier onlyRegulatoryAuthority{
        (IRegistration.EntityType entitytype, bool isRegistered) = Registration.getEntity(msg.sender);
        require(entitytype == IRegistration.EntityType.RegulatoryAuthority && isRegistered, "Only the regulatory authority can run this function");
        _;
    }

    modifier onlyDistributor{
        (IRegistration.EntityType entitytype, bool isRegistered) = Registration.getEntity(msg.sender);
        require(entitytype == IRegistration.EntityType.Distributor && isRegistered, "Only a distributor can execute this function");
        _;
    }

    //**** Events ****//
    event RefinedMineralsEnRoute(address distributor, address _receiver, uint256 refinedMineralsID);
    event RefinedMineralsDelivered(address distributor, address _receiver, uint256 refinedMineralsID);
    event BatteryLotEnRoute(address distributor, address _receiver, uint256 batteryLotID);
    event BatteryLotDelivered(address distributor, address _receiver, uint256 batteryLotID);
    event RMSignatureStorage(address indexed verifiedAddress, address indexed redeemer, address indexed RM, uint rmtokenId, string message, bytes signature);
    event BLotSignatureStorage(address indexed verifiedAddress, address indexed redeemer, address indexed BLot, uint blottokenId, string message, bytes signature);



    //**** Functions ****//

    function startRefinedMineralsDelivery(address _receiver, uint256 refinedMineralsID) external onlyDistributor{
        require(RefinedMinerals.ownerOf(refinedMineralsID) == _receiver, "The receiver of the refined minerals must be the current owner");
        require(rMState[refinedMineralsID] == refinedMineralsState.Pending, "This Lot has already been picked up");
        
        rMState[refinedMineralsID] = refinedMineralsState.EnRoute;

        emit RefinedMineralsEnRoute(msg.sender, _receiver, refinedMineralsID);
    }

    //The NFT ownership of the receiver confirms their eligibility to receive the item
    function endRefinedMineralsDelivery(address _receiver, uint256 refinedMineralsID) external onlyDistributor{
        Signature storage rmSig = rmSignatures[refinedMineralsID];
        require(rmSig.receiver == _receiver,"The signature of the receiver does not exist or invalid");
        require(RefinedMinerals.ownerOf(refinedMineralsID) == _receiver, "The receiver of the refined minerals must be the current owner");        
        require(rMState[refinedMineralsID] == refinedMineralsState.EnRoute, "This refined minerals has not been picked up yet or has already been delivered");
        
        rMState[refinedMineralsID] = refinedMineralsState.Delivered;
        
        emit RefinedMineralsDelivered(msg.sender, _receiver, refinedMineralsID);
    }

    //Optional: Multiple Lots can be delivered by using an array of IDs
    function startBatteryLotDelivery(address _receiver, uint256 batteryLotID) external onlyDistributor{
        require(BatteriesLOT.ownerOf(batteryLotID) == _receiver, "The receiver of the Battery Lot must be the current owner");
        require(bLotState[batteryLotID] == batteryLotState.Pending, "This Lot has already been picked up");
        
        bLotState[batteryLotID]= batteryLotState.EnRoute;

        emit BatteryLotEnRoute(msg.sender, _receiver, batteryLotID);
    }

    //The confirmation via digital signatures is not included. For details, refer to https://www.sciencedirect.com/science/article/pii/S0959652622031973
    //The NFT ownership of the receiver confirms their eligibility to receive the item
    function endBatteryLotDelivery(address _receiver, uint256 batteryLotID) external onlyDistributor{
        Signature storage bLotSig = bLotSignatures[batteryLotID];
        require(bLotSig.receiver == _receiver,"The signature of the receiver does not exist or invalid");
        require(BatteriesLOT.ownerOf(batteryLotID) == _receiver, "The receiver of the Battery Lot must be the current owner");        
        require(bLotState[batteryLotID] == batteryLotState.EnRoute, "This battery Lot has not been picked up yet or has already been delivered");
        
        bLotState[batteryLotID] = batteryLotState.Delivered;
        
        emit BatteryLotDelivered(msg.sender, _receiver, batteryLotID);
    }

    //A signature confirming the reception of the delivered item by the manufacturer must be signed first before the distributor can end delivery
    function storeRMSignatures(string memory message, bytes memory sig, uint256 refinedMineralsID) public {
        require(isValidSignature(message,sig) == RefinedMinerals.ownerOf(refinedMineralsID), "Invalid signature"); //if they match then it confirms the receiver is the data owner

        rmSignatures[refinedMineralsID] = Signature (RefinedMinerals.ownerOf(refinedMineralsID), address(RefinedMinerals),refinedMineralsID, message, sig);

        emit RMSignatureStorage(isValidSignature(message,sig), RefinedMinerals.ownerOf(refinedMineralsID), address(RefinedMinerals),  refinedMineralsID,  message,  sig);
    }

    //A signature confirming the reception of the delivered item by the retailer must be signed first before the distributor can end delivery
    function storeBLotSignatures(string memory message, bytes memory sig, uint256 BLotID) public {
        require(isValidSignature(message,sig) == BatteriesLOT.ownerOf(BLotID), "Invalid signature"); //if they match then it confirms the receiver is the data owner

        bLotSignatures[BLotID] = Signature (BatteriesLOT.ownerOf(BLotID), address(BatteriesLOT),BLotID, message, sig);

        emit BLotSignatureStorage(isValidSignature(message,sig), BatteriesLOT.ownerOf(BLotID), address(BatteriesLOT),  BLotID,  message,  sig);
    }

    // Returns the public address that signed a given string message (Message Signing)
    function isValidSignature(string memory message, bytes memory sig) public pure returns (address signer) {

        bytes32 r;
        bytes32 s;
        uint8 v;
        assembly {
        r := mload(add(sig, 32))
        s := mload(add(sig, 64))
        v := and(mload(add(sig, 65)), 255)
        }
        
        if (v < 27) v += 27;

        // The message header; we will fill in the length next
        string memory header = "\x19Ethereum Signed Message:\n000000";
        uint256 lengthOffset;
        uint256 length;
        assembly {
        // The first word of a string is its length
        length := mload(message)
        // The beginning of the base-10 message length in the prefix
        lengthOffset := add(header, 57)
        }
        // Maximum length we support
        require(length <= 999999);
        // The length of the message's length in base-10
        uint256 lengthLength = 0;
        // The divisor to get the next left-most message length digit
        uint256 divisor = 100000;
        // Move one digit of the message length to the right at a time
        while (divisor != 0) {
        // The place value at the divisor
        uint256 digit = length / divisor;
        if (digit == 0) {
            // Skip leading zeros
            if (lengthLength == 0) {
            divisor /= 10;
            continue;
            }
        }
        // Found a non-zero digit or non-leading zero digit
        lengthLength++;
        // Remove this digit from the message length's current value
        length -= digit * divisor;
        // Shift our base-10 divisor over
        divisor /= 10;
        
        // Convert the digit to its ASCII representation (man ascii)
        digit += 0x30;
        // Move to the next character and write the digit
        lengthOffset++;
        assembly {
            mstore8(lengthOffset, digit)
        }
        }
        // The null string requires exactly 1 zero (unskip 1 leading 0)
        if (lengthLength == 0) {
        lengthLength = 1 + 0x19 + 1;
        } else {
        lengthLength += 1 + 0x19;
        }
        // Truncate the tailing zeros from the header
        assembly {
        mstore(header, lengthLength)
        }
        // Perform the elliptic curve recover operation
        bytes32 check = keccak256(abi.encodePacked(header, message));
        return ecrecover(check, v, r, s); 
  }

}




//NOTE: After starting the delivery, the package can be monitored as in https://ieeexplore.ieee.org/document/9427467
