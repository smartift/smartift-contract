pragma solidity ^0.4.11;

contract AdminManagedContract {
    /* Map our users to admins */
    mapping (address => bool) adminUsers;

    /* Details of all admins that have ever existed */
    address[] adminAudit;

    /* Fired whenever an admin is added to the contract. */
    event AdminAdded(address admin);

    /* Fired whenever an admin is removed from the contract. */
    event AdminRemoved(address admin);

    /* This modifier allows a method to only be caleld by current admins */
    modifier adminOnly {
        if (!adminUsers[msg.sender]) throw;
        _;
    }

    /* Gets whether or not the specified address is currently an admin */
    function adminCheckCurrently(address _address) constant returns (bool _isAdmin) {
        _isAdmin = adminUsers[_address];
    }
    /* Gets whether or not the specified address has ever been an admin */
    function adminCheckEver(address _address) constant returns (bool _isAdmin) {
        _isAdmin = false;
        for (uint256 i = 0; i < adminAudit.length; i++)
            if (adminAudit[i] == _address) {
                _isAdmin = true;
                break;
            }
    }

    /* Adds a user to our list of admins */
    function adminAdminAdd(address _address) adminOnly {
        adminUsers[_address] = true;
        AdminAdded(msg.sender);
        adminAudit.length++;
        adminAudit[adminAudit.length - 1] = _address;
    }

    /* Removes a user from our list of admins but keeps them in the history audit */
    function adminAdminRemove(address _address) adminOnly {
        /* Don't allow removal of self */
        if (_address == msg.sender)
            throw;

        /* Remove this admin user */
        adminUsers[_address] = false;
        AdminRemoved(_address);
    }
}