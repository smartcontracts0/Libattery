// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

contract RegistrationContract {
    enum EntityType {RegulatoryAuthority, Miner, Refinery, Manufacturer, Distributor, Retailer}
    struct Entity {
        EntityType entityType;
        bool isRegistered;
    }

    mapping(address => Entity) public entities;

    event EntityRegistered(address indexed entityAddress, EntityType entityType);

    modifier onlyEntity(EntityType _entityType) {
        require(entities[msg.sender].entityType == _entityType, "Only authorized entity can perform this action");
        _;
    }

    constructor() {
        // Register the regulatory authority upon contract deployment
        entities[msg.sender] = Entity({
            entityType: EntityType.RegulatoryAuthority,
            isRegistered: true
        });
        
        emit EntityRegistered(msg.sender, EntityType.RegulatoryAuthority);
    }

    function registerEntity(address _entityAddress, EntityType _entityType) external onlyEntity(EntityType.RegulatoryAuthority) {
        require(_entityAddress != address(0), "Invalid entity address");
        require(!entities[_entityAddress].isRegistered, "This entity has already been registered");

        entities[_entityAddress].entityType = _entityType;
        entities[_entityAddress].isRegistered = true;

        emit EntityRegistered(_entityAddress, _entityType);
    }

    function  removeEntity(address _entityAddress) external onlyEntity(EntityType.RegulatoryAuthority) {
        require(_entityAddress != address(0), "Invalid entity address");

        delete(entities[_entityAddress]);
    }

    function getEntity(address _entityAddress) public view returns (EntityType, bool) {
        Entity storage entity = entities[_entityAddress];
        return (entity.entityType, entity.isRegistered);
    }


}