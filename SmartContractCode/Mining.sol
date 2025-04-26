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
        function ownerOf(uint256 tokenId) external view returns (address owner);
        //function transferFrom(address from, address to, uint256 tokenId) external;
    }

    interface IWasteManagement{
        function _disposeItem(address, address, uint256 , string memory) external;
    }

//This contract is used to ensure responsible sourcing in the initial stage
contract MiningContract {

    //**** State Variable ****//
    IRefinedMinerals public RefinedMinerals;
    IRegistration public Registration;
    IWasteManagement public WasteManagement;
    uint256 private leaseNumberCounter;
    uint256 public requestNumber;
    //Note: A request Number can be added for each mining request to allow a miner to request mining for the same location twice
    //uint256 private AvailableMinerals; //Sums the total weight (KG) of the mined minerals



    struct MiningLease {
        address regulatoryAuthority;
        address miner;
        uint256 leaseNumber;
        uint256 miningLocation;
        uint256 approvalTime;
        uint256 leasePeriod;
        bool approvalStatus; //This checks if the miningLease is active or not
    }

    struct MinedMinerals{
        address miner;
        uint256 mineralsQuantity; //Here it is assumed that the quantity of the collected minerals ( lithium, cobalt, nickel, manganese, aluminum, and copper) is measured in KGs
        uint256 miningLocation;
        uint256 leaseNumber;
        uint256 date; 
        bool isRefined;
    }

    struct ViolationDetails{
        address miner;
        uint256 leaseNumber;
        uint256 miningLocation;
        uint256 date;
        uint256 violationNumber;
        bytes32 IPFShash;
        bool isResolved;
        bool isViolation; // True if the violation is legit, false otherwise
    }

    //miner address => (requestNumber => (mining location ID => lease period))
    mapping(address => mapping(uint256 => mapping(uint256 => uint256))) public miningApprovalRequest;

    //miner address => (mining location ID => bool)
    //Checks if the mining approval request is pending or not
    mapping(address => mapping(uint256 => mapping(uint256 => bool))) public miningRequestPending; 
    //miner address => (location ID => bool) 
    //This mapping maps the approval of the address of the miner to a certain location
    mapping(address => mapping(uint256 => mapping(uint256 => bool))) public miningApprovalStatus;

    //mining location => (miner address => lease period (days))
    //mapping(uint256 => mapping(address => uint256)) public miningLeasePeriod; 

    // miner address => (location => MiningLeaseDetails)
    mapping(address => mapping(uint256 => MiningLease)) public miningLeaseDetails; 


    //miner => (lease number => counter)
    mapping(address => mapping(uint256 => uint256)) public miningCounter;
    //miner => (lease number => (miningcounter => minedmineralsinformation)
    mapping(address => mapping(uint256 => mapping(uint256 => MinedMinerals))) public minedMineralsInformation;
    
    //Miner =>(lease number => Available Minerals)
    mapping(address => mapping(uint256 => uint256)) public AvailableMinerals;
    
    //miner => (leaseNumber => counter)
    mapping(address => mapping(uint256 => uint256)) public violationCounter;

    // violatingminer =>(leaseNumber => (violation number => IPFShash))
    mapping(address => mapping(uint256 => mapping(uint256 => ViolationDetails))) public reportedViolation;

    //miner => (lease number =>(violation number => bool))
    mapping(address => mapping(uint256 => mapping(uint256 => bool))) public violationConfirmed;

    //**** Constructor ****//
    constructor(address _registration, address _refinedmineralSC, address _wastemgmt){
        Registration = IRegistration(_registration);
        RefinedMinerals = IRefinedMinerals(_refinedmineralSC);
        WasteManagement = IWasteManagement(_wastemgmt);

    }

    //**** Modifiers ****//

    modifier onlyRegulatoryAuthority{
        (IRegistration.EntityType entitytype, bool isRegistered) = Registration.getEntity(msg.sender);
        require(entitytype == IRegistration.EntityType.RegulatoryAuthority && isRegistered, "Only the regulatory authority can run this function");
        _;
    }

    modifier onlyMiner{
        (IRegistration.EntityType entitytype, bool isRegistered) = Registration.getEntity(msg.sender);
        require(entitytype == IRegistration.EntityType.Miner && isRegistered, "Only miners can execute this function");
        _;
    }

    modifier onlyRefinery{
        (IRegistration.EntityType entitytype, bool isRegistered) = Registration.getEntity(msg.sender);
        require(entitytype == IRegistration.EntityType.Refinery && isRegistered, "Only the refinery can execute this function");
        _;
    }

    

    //**** Events ****//
    event MiningPermissionRequest(address miner, uint256 requestNumber, uint256 mininglocation);
    event MiningPermissionApproved(address regulatoryauthority, address miner, uint256 requestNumber, uint256 location, uint256 leasePeriod);
    event MinedMineralsDetails(address miner, uint256 leasenumber, uint256 location, uint256 quantity);
    event ViolationReported(address reporter, address miner, uint256 leasenumber, uint256 location, uint256 date, bytes32 IPFShash);
    event MinedMineralsRefined(address refinery, uint256 leaseNumber, uint256 refinedquantity, uint256 date);
    event MiningPermissionRevoked(address regulatoryAuthority, address miner, uint256 location, string reason);
    event ViolationResolution(address regulatoryAuthority, address miner, uint256 location, uint256 leaseNumber, uint256 _violationNumber, bool isViolation);
    event RefinedMineralsDisposed(address disposer, uint256 RefinedMineralsID, bytes32 IPFShash);

    //**** Functions ****//

    //Function1: Mining lease signing, it should be revoked by chainlink's upkeep
    function requestMiningPermission(uint256 _location, uint256 _leasePeriod) external onlyMiner{
        requestNumber++;
        miningApprovalRequest[msg.sender][requestNumber][_location] = _leasePeriod * 1 days;
        miningRequestPending[msg.sender][requestNumber][_location] = true;
        emit MiningPermissionRequest(msg.sender,requestNumber, _location);
    }

    function approveMiningPermission(address _miner, uint256 _requestNumber, uint256 _location) external onlyRegulatoryAuthority{
        require(miningRequestPending[_miner][_requestNumber][_location], "The miner has not requested approval for this location, or it has already been approved");
        require(!miningApprovalStatus[_miner][_requestNumber][_location], "This request has already been approved");
        uint256 leasePeriod = miningApprovalRequest[_miner][_requestNumber][_location];
        leaseNumberCounter++;
        miningApprovalStatus[_miner][_requestNumber][_location] = true; //

        miningLeaseDetails[_miner][_location] = MiningLease (msg.sender, _miner, leaseNumberCounter, _location, block.timestamp, leasePeriod, miningApprovalStatus[_miner][_requestNumber][_location]);
        
        emit MiningPermissionApproved(msg.sender, _miner,requestNumber, _location, leasePeriod);

    }

    // Permission is revoked due to a violation or leasing period expiring, NOTE: Revoking due to lease expiry can be performed by an oracle such as Chainlink's upkeep network service, and it should be in a seperate function
    function revokeMiningPermission(address _miner, uint256 _location) external onlyRegulatoryAuthority {
        MiningLease storage MLDetails = miningLeaseDetails[_miner][_location];
        require(MLDetails.approvalStatus || block.timestamp > (MLDetails.approvalTime + MLDetails.leasePeriod), "The mining permission for this lease has already been revoked");
        MLDetails.approvalStatus = false;
        emit MiningPermissionRevoked(msg.sender, _miner, _location, "timeexpired");
    }

    //Function2: Store Production details such as date and time of extraction, location, quanitity, equipment/machinery involved parties
    //Capturing data can be automated by IoT devices and sensors
    function storeMinedMineralsInfo(uint256 _location, uint256 _mineralsQuantity) external onlyMiner{
        MiningLease storage MLDetails = miningLeaseDetails[msg.sender][_location];
        require(MLDetails.approvalStatus, "This miner is not approved to mine in this location, or the approval has already expired or revoked");
        require(block.timestamp < (MLDetails.approvalTime + MLDetails.leasePeriod), "The lease period has expired");
        
        minedMineralsInformation[msg.sender][MLDetails.leaseNumber][miningCounter[msg.sender][MLDetails.leaseNumber]] = MinedMinerals(msg.sender, _mineralsQuantity, MLDetails.miningLocation, MLDetails.leaseNumber, block.timestamp, false);

        miningCounter[msg.sender][MLDetails.leaseNumber]++;

        emit MinedMineralsDetails(msg.sender, MLDetails.leaseNumber, MLDetails.miningLocation, _mineralsQuantity);
    }

    //Function3: Refine Mined Materials
    //1. require minedmaterial not refined yet, 2. update to refined after completion, 3. an NFT for refined material should be minted, what else?
    function refineMinedMinerals(address _miner, uint256 _location) external onlyRefinery{
        MiningLease storage MLDetails = miningLeaseDetails[_miner][_location];

        for(uint256 i = 0; i < miningCounter[_miner][MLDetails.leaseNumber]; i++){
            MinedMinerals storage MMDetails = minedMineralsInformation[MLDetails.miner][MLDetails.leaseNumber][i];
            require(!minedMineralsInformation[MLDetails.miner][MLDetails.leaseNumber][i].isRefined, "This quantity has already been refined");
            AvailableMinerals[_miner][MLDetails.leaseNumber] += MMDetails.mineralsQuantity;
            minedMineralsInformation[MLDetails.miner][MLDetails.leaseNumber][i].isRefined = true;
            emit MinedMineralsRefined(msg.sender, MLDetails.leaseNumber, MMDetails.mineralsQuantity, block.timestamp);
        }

        if(AvailableMinerals[_miner][MLDetails.leaseNumber] >=10){
            uint256 nftQuantity = AvailableMinerals[_miner][MLDetails.leaseNumber]/10;
            for(uint256 i = 0; i < nftQuantity; i++){
                RefinedMinerals.mintRefinedMaterialPackage(msg.sender);
            }
            AvailableMinerals[_miner][MLDetails.leaseNumber] %= 10; //stores the remaining refined minerals
        }

    }

    //Function4: Report violations based on inspections or whistle-blow
    function reportViolation(address _miner, uint256 _location, string memory _IPFShash) external {
        MiningLease storage MLDetails = miningLeaseDetails[_miner][_location];

        violationCounter[_miner][MLDetails.leaseNumber]++;

        reportedViolation[_miner][MLDetails.leaseNumber][violationCounter[_miner][MLDetails.leaseNumber]] = ViolationDetails(_miner, MLDetails.leaseNumber, MLDetails.miningLocation, block.timestamp, violationCounter[_miner][MLDetails.leaseNumber], bytes32(bytes(_IPFShash)), false, false);

        emit ViolationReported(msg.sender, _miner, MLDetails.leaseNumber,MLDetails.miningLocation,  block.timestamp,   bytes32(bytes(_IPFShash)));
    }

    //The reported violation should be inspected and a decision is made. If the decision confirms the violation, the regulator can execute the revokePermission function    

    function resolveViolation(address _miner, uint256 _location, uint256 _violationNumber, bool _decision) external onlyRegulatoryAuthority{
        
        MiningLease storage MLDetails = miningLeaseDetails[_miner][_location];
        ViolationDetails storage VDetails = reportedViolation[_miner][MLDetails.leaseNumber][_violationNumber];
        require(_violationNumber > 0 && _violationNumber <= violationCounter[_miner][MLDetails.leaseNumber], "The violation number is invalid");
        require(!VDetails.isResolved, "This violation has already been resovled");        

        VDetails.isViolation = _decision;
        VDetails.isResolved = true;

        if(VDetails.isViolation){
        MLDetails.approvalStatus = false;
        emit MiningPermissionRevoked(msg.sender, _miner, _location, "Violation");            
        }
        emit ViolationResolution(msg.sender, _miner, _location, MLDetails.leaseNumber, _violationNumber, _decision);
    
    }

    function disposeRefinedMinerals(uint256 RefinedMineralsID,  string memory _IPFShash) public {
        require(msg.sender == RefinedMinerals.ownerOf(RefinedMineralsID), "Only the current battery owner can execute this function");
        RefinedMinerals.transferFrom(msg.sender, address(WasteManagement), RefinedMineralsID); //The WasteManagement SC must be approved first
        WasteManagement._disposeItem(msg.sender, address(RefinedMinerals), RefinedMineralsID , _IPFShash);
        emit RefinedMineralsDisposed(msg.sender, RefinedMineralsID, bytes32(bytes(_IPFShash)));

    }

}