// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract MRV_Solution{
    
    enum Outcome {Pending, Verified, Disputed, Rejected}
    enum Role {Regulator, Auditor, Personnel, Sensor}
    enum Source {Personnel, Automated}

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
        Source source;
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
    uint public audit_firm_count;

    // Mapping and Arrays
    mapping(address => bool) public regulators;
    mapping(address => bool) public personnel;
    mapping(address => bool) public sensors;
    mapping(address => bool) public auditors; 
    Facility[] public facilities;
    EmissionsRecord[] public emission_records;
    mapping(uint => string) public audit_firm_name;
    mapping(address => uint) public auditor_to_firm;
    mapping(uint => VerificationDetails[]) public record_verifications;

    //custom errors
    error NotAdmin(address caller);
    error NotRegulator(address caller);
    error NotAuditor(address caller);
    error InvalidAuditFirm(uint audit_firm_id);
    error NotAuthorisedSubmitter (address caller);
    error ZeroAddress();
    error AlreadyHasRole(address account, Role role);
    error DoesNotHaveRole(address account, Role role);

          // Event fired on role assignment/removal
    event RoleGranted (
        Role indexed _role,
        address indexed _account,
        address _grantedby
    );

    event RoleRevoked (
        Role indexed _role,
        address indexed _account,
        address _revokedby
    );

    // Event fired on transfer of admin rights
    event AdminTransferred (
        address indexed _previous_admin,
        address indexed _new_admin
    );

    // Event fired on registration of facility
    event FacilityRegistered (
        uint indexed _facility_id,
        address _registered_by
    );

    // Event fired on registration of audit firm
    event AuditFirmRegistered (
        uint indexed _audit_firm_id,
        address _registered_by
    );

    // Event fired on submission of record
    event RecordSubmitted (
        uint indexed _record_id,
        uint indexed _facility_id,
        bytes32 _data_hash
    );

    // Event registered when verification appended
    event VerificationAppended (
        uint indexed _record_id,
        uint indexed _audit_firm_id,
        Outcome indexed _outcome
    );
  

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

    modifier onlyAuthorisedSubmitter() {
        if (!sensors[msg.sender] && !personnel[msg.sender]) {
            revert NotAuthorisedSubmitter(msg.sender);
        }
        _;
    }

    // constructor
    constructor () {
        admin = msg.sender;
        emit AdminTransferred(address(0), msg.sender);
    }

    //functions to grant roles
    function grantRegulator (address account) external onlyAdmin {
        if (account == address(0)) revert ZeroAddress();
        if (regulators[account]) revert AlreadyHasRole(account, Role.Regulator);
        regulators[account] = true;
        emit RoleGranted(Role.Regulator, account, msg.sender);
    }
    function grantAuditor (address account, uint _audit_firm_id) external onlyAdmin {
        if (account == address(0)) revert ZeroAddress();
        if (auditors[account]) revert AlreadyHasRole(account, Role.Auditor);
        if (_audit_firm_id ==0 || _audit_firm_id > audit_firm_count) revert InvalidAuditFirm(_audit_firm_id);
        auditors[account] = true;
        auditor_to_firm[account] = _audit_firm_id;
        emit RoleGranted(Role.Auditor, account, msg.sender);
    }
    function grantPersonnel (address account) external onlyAdmin {
        if (account == address(0)) revert ZeroAddress();
        if (personnel[account]) revert AlreadyHasRole(account, Role.Personnel);
        personnel[account] = true;
        emit RoleGranted(Role.Personnel, account, msg.sender);
    }
    function grantSensor (address account) external onlyAdmin {
        if (account == address(0)) revert ZeroAddress();
        if (sensors[account]) revert AlreadyHasRole(account, Role.Sensor);
        sensors[account] = true;
        emit RoleGranted(Role.Sensor, account, msg.sender);
    }

    //functions to revoke roles
     function revokeRegulator (address account) external onlyAdmin {
        if (!regulators[account]) revert DoesNotHaveRole(account, Role.Regulator);
        regulators[account] = false;
        emit RoleRevoked(Role.Regulator, account, msg.sender);
    }
    function revokeAuditor (address account) external onlyAdmin {
        if (!auditors[account]) revert DoesNotHaveRole(account, Role.Auditor);
        auditors[account] = false;
        auditor_to_firm[account] = 0;
        emit RoleRevoked(Role.Auditor, account, msg.sender);
    }
    function revokePersonnel (address account) external onlyAdmin {
        if (!personnel[account]) revert DoesNotHaveRole(account, Role.Personnel);
        personnel[account] = false;
        emit RoleRevoked(Role.Personnel, account, msg.sender);
    }
    function revokeSensor (address account) external onlyAdmin {
        if (!sensors[account]) revert DoesNotHaveRole(account, Role.Sensor);
        sensors[account] = false;
        emit RoleRevoked(Role.Sensor, account, msg.sender);
    }
}
