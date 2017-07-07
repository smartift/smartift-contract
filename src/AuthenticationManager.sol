pragma solidity ^0.4.11;

/* The authentication manager details user accounts that have access to certain priviledges and keeps a permanent ledger of who has and has had these rights. */
contract AuthenticationManager {
    /* Map our users to admins */
    mapping (address => bool) adminUsers;

    /* Details of all admins that have ever existed */
    address[] adminAudit;

    /* Fired whenever an admin is added to the contract. */
    event AdminAdded(address addedBy, address admin);

    /* Fired whenever an admin is removed from the contract. */
    event AdminRemoved(address removedBy, address admin);

    /* When this contract is first setup we use the creator as the first admin */    
    function AuthenticationManager() {
        /* Set the first admin to be the person creating the contract */
        adminUsers[msg.sender] = true;
        AdminAdded(0, msg.sender);
        adminAudit.length++;
        adminAudit[adminAudit.length - 1] = msg.sender;
    }

    /* Gets the contract version for validation */
    function contractVersion() constant returns(uint256) {
        // Admin contract identifies as 100YYYYMMDDHHMM
        return 100201707071124;
    }

    /* Gets whether or not the specified address is currently an admin */
    function isCurrentAdmin(address _address) constant returns (bool _isAdmin) {
        _isAdmin = adminUsers[_address];
    }

    /* Gets whether or not the specified address has ever been an admin */
    function isCurrentOrPastAdmin(address _address) constant returns (bool _isAdmin) {
        _isAdmin = false;
        for (uint256 i = 0; i < adminAudit.length; i++)
            if (adminAudit[i] == _address) {
                _isAdmin = true;
                break;
            }
    }

    /* Adds a user to our list of admins */
    function add(address _address) {
        /* Ensure we're an admin */
        if (!isCurrentAdmin(msg.sender))
            throw;

        // Fail if this account is already admin
        if (adminUsers[_address])
            throw;
        
        // Add the user
        adminUsers[_address] = true;
        AdminAdded(msg.sender, _address);
        adminAudit.length++;
        adminAudit[adminAudit.length - 1] = _address;
    }

    /* Removes a user from our list of admins but keeps them in the history audit */
    function remove(address _address) {
        /* Ensure we're an admin */
        if (!isCurrentAdmin(msg.sender))
            throw;

        /* Don't allow removal of self */
        if (_address == msg.sender)
            throw;

        // Fail if this account is already non-admin
        if (!adminUsers[_address])
            throw;

        /* Remove this admin user */
        adminUsers[_address] = false;
        AdminRemoved(msg.sender, _address);
    }
}