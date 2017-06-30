pragma solidity ^0.4.11;
import "AdminManagedContract.sol";

contract IcoPhasedContract is AdminManagedContract {
    /* Defines whether or not we are in the ICO phase */
    bool icoPhase = true;

    /* Defines our event fired when the ICO is closed */
    event IcoClosed();
    
    /* Ensures a function can only be called during the ICO */
    modifier onlyDuringIco {
        if (!icoPhase) throw;
        _;
    }
    /* Ensures a function can only be called after the ICO */
    modifier onlyAfterIco {
        if (icoPhase) throw;
        _;
    }

    /* Close the ICO phase and transition to execution phase */
    function closeIco() adminOnly onlyDuringIco {
        icoPhase = false;
        IcoClosed();
    }
}