// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract MRV_Solution{
    
    enum Outcome {Pending, Verified, Disputed, Rejected}

    //Facility Struct
    struct Facility {
        uint facility_id; // facitlity identifier
        string facility_name; // actual facility name - included for ease of reference
        address registered_by; // important for audit trail/tracking - using address
        bool is_active; // is the facility still operational
    }
    
    // Emissions Record Struct
    struct EmissionsRecord{
        uint record_id;
        uint facility_id; // facitlity identifier
        bytes32 data_hash; // hash of emmissions data - hashed for security
        address submitted_by; // important for audit trail and tracking - using address
        uint submitted_when; // submission timestamp - but using block.timestamp
        
    }

    // Verification Struct
    struct VerificationDetails {
        uint record_id; // emissions record identifier
        uint audit_firm_id; // audit firm identifier
        uint audit_time; // audit timestamp - using block.timestamp
        Outcome outcome;
        bytes32 comments_hash; // hashed audit comments 
    }   

    // Other state variables
    address public admin;

    // Mapping and Arrays
    mapping(address => bool) public regulators;
    mapping(address => bool) public personnel;
    mapping(address => bool) public auditors; 
    Facility[] public facilities;
    EmissionsRecord[] public emission_records;
    mapping(uint => string) public audit_firm_name;
    mapping(address => uint) public auditor_to_firm;
    mapping(uint => VerificationDetails[]) public record_verifications;

    //errors
    error NotAdmin(address caller);
    error NotRegulator(address caller);
    error NotAuditor(address caller);
    error NotAuthorisedPersonnel(address caller);
    error AlreadyVerifier(address caller);

    // Roles and modifiers
    modifier onlyAdmin() {
        if (msg.sender != admin) {
            revert NotAdmin(msg.sender);
        } 
        _;
    }

    modifier onlyRegulator() {
        if (!regulators[msg.sender]) {
            revert NotRegulator(msg.sender);
        }
        _;

    }

    modifier onlyAuditor() {
        if (!auditors[msg.sender]) {
            revert NotAuditor(msg.sender);
        }
        _;
    }

    modifier onlyAuthorisedPersonnel() {
        if (!personnel[msg.sender]) {
            revert NotAuthorisedPersonnel(msg.sender);
        }
        _;
    }
}
