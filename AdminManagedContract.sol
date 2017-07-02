pragma solidity ^0.4.11;

contract AdminManagedContract {
    /* Map our users to admins */
    mapping (address => bool) adminUsers;

    /* Fired whenever an admin is added to the contract. */
    event AdminAdded(address admin);

    /* Fired whenever an admin is removed from the contract. */
    event AdminRemoved(address admin);

    function AdminManagedContract() {
    }

    modifier adminOnly {
        if (!adminUsers[msg.sender]) throw;
        _;
    }

    function adminAdd(address adminAddress) adminOnly {
        adminUsers[adminAddress] = true;
        AdminAdded(msg.sender);
    }


    function adminRemove(address adminAddress) adminOnly {
        // Don't allow removal of self
        if (adminAddress == msg.sender)
            throw;

        // Remove this admin user
        adminUsers[adminAddress] = false;
        AdminRemoved(adminAddress);
    }
}