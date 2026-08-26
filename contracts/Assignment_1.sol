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
    error NoNameProvided();
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

    // Events fired on deactivaton and reactivation of facility
    event FacilityStatusChanged(
        uint indexed _facility_id,
        bool _is_active,
        address _changed_by
    );

    // Event fired on registration of audit firm
    event AuditFirmRegistered (
        uint indexed _audit_firm_id,
        address _registered_by
    );

    // Event fired on submission of record
    event EmissionsRecordSubmitted (
        uint indexed _record_id,
        uint indexed _facility_id,
        bytes32 _data_hash,
        Source _source
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

    //Register Facility Function
   function registerFacility(string calldata _facility_name) external onlyRegulator returns (uint){
        if  (bytes(_facility_name).length == 0) revert NoNameProvided();
        uint _facility_id = facilities.length;
        facilities.push(Facility(_facility_id, _facility_name, msg.sender, true));
        emit FacilityRegistered(_facility_id, msg.sender);
        return _facility_id;
    }

    // Register Audit Firm
    function registerAuditFirm(string calldata _audit_firm_name) external onlyRegulator returns(uint){
        if (bytes(_audit_firm_name).length == 0) revert NoNameProvided();
        audit_firm_count ++;
        uint _audit_firm_id = audit_firm_count;
        audit_firm_name[_audit_firm_id] = _audit_firm_name;
        emit AuditFirmRegistered(_audit_firm_id, msg.sender);
        return _audit_firm_id;
    }


    //Submit Emissions Record
    function submitEmissionRecord(uint _facility_id, bytes32 _data_hash) external onlyAuthorisedSubmitter returns (uint){
        require (_facility_id < facilities.length, "Facility does not exist");
        require (facilities[_facility_id].is_active, "Inactive facility");
        require (_data_hash != bytes32(0), "Emission record is empty");
        Source source = sensors[msg.sender] ? Source.Automated : Source.Personnel;
        uint _record_id = emission_records.length;
        emission_records.push(EmissionsRecord(_record_id, _facility_id, _data_hash, msg.sender, source, block.timestamp));
        emit EmissionsRecordSubmitted(_record_id, _facility_id, _data_hash, source);
        return _record_id;

    }

    //Verification Appended
    function appendVerification(uint _record_id, Outcome _outcome, bytes32 _comments_hash) external onlyAuditor returns (uint){
        require (_record_id < emission_records.length, "Emissions record does not exist");
        require (_outcome != Outcome.Pending, "Verification in progress cannot submit");
        uint _audit_firm_id = auditor_to_firm[msg.sender];
        record_verifications[_record_id].push(VerificationDetails(_record_id, _audit_firm_id, block.timestamp, _outcome, _comments_hash));
        emit VerificationAppended(_record_id, _audit_firm_id, _outcome);
        return record_verifications[_record_id].length - 1;

    }

    //Transfer Admin function
    function transferAdmin(address _new_admin) external onlyAdmin {
        if (_new_admin == address(0)) revert ZeroAddress();
        address _previous_admin = admin;
        admin = _new_admin;
        emit AdminTransferred(_previous_admin, _new_admin);

    }

    //function to deactivate facility
    function deactivateFacility(uint _facility_id) external onlyRegulator {
        require (_facility_id < facilities.length, "Facility does not exist");
        require (facilities[_facility_id].is_active, "Facility is already inactive");
        facilities[_facility_id].is_active = false;
        emit FacilityStatusChanged(_facility_id, false, msg.sender);
    }

    // function to reactivate facility
    function reactivateFacility(uint _facility_id) external onlyRegulator {
        require (_facility_id < facilities.length, "Facility does not exist");
        require (!facilities[_facility_id].is_active, "Facility is already active");
        facilities[_facility_id].is_active = true;
        emit FacilityStatusChanged(_facility_id, true, msg.sender);
    }


    //Function to view emission record fro verification
    function getRecordVerifications(uint _record_id) external view returns (VerificationDetails[] memory) {
        require (_record_id < emission_records.length, "Emission record does not exist");
        return record_verifications[_record_id];

    }

    //count functions
    function numberofFacilities() external view returns (uint) {
        return facilities.length;
    }

    function numberofEmissionRecords() external view returns (uint) {
        return emission_records.length;
    }
        
} 