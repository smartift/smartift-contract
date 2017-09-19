pragma solidity ^0.4.11;
import "AuthenticationManager.sol";
import "SmartInvestmentFundToken.sol";
import "SafeMath.sol";

contract TokenHolderSnapshotter {
    using SafeMath for uint256;

    /* Map all our our balances for issued tokens */
    mapping (address => uint256) balances;

    /* Our handle to the SIFT contract. */
    SmartInvestmentFundToken siftContract;

    /* Defines the admin contract we interface with for credentails. */
    AuthenticationManager authenticationManager;

    /* List of all token holders */
    address[] allTokenHolders;

    /* Fired whenever a new snapshot is made */
    event SnapshotTaken();
    event SnapshotUpdated(address holder, uint256 oldBalance, uint256 newBalance, string details);

    /* This modifier allows a method to only be called by current admins */
    modifier adminOnly {
        if (!authenticationManager.isCurrentAdmin(msg.sender)) throw;
        _;
    }
    /* This modifier allows a method to only be called by account readers */
    modifier accountReaderOnly {
        if (!authenticationManager.isCurrentAccountReader(msg.sender)) throw;
        _;
    }

    /* Create our contract with references to other contracts as required. */
    function TokenHolderSnapshotter(address _siftContractAddress, address _authenticationManagerAddress) {
        /* Setup access to our other contracts and validate their versions */
        siftContract = SmartInvestmentFundToken(_siftContractAddress);
        if (siftContract.contractVersion() != 500201707171440)
            throw;

        /* Setup access to our other contracts and validate their versions */
        authenticationManager = AuthenticationManager(_authenticationManagerAddress);
        if (authenticationManager.contractVersion() != 100201707171503)
            throw;
    }

    /* Gets the contract version for validation */
    function contractVersion() constant returns(uint256) {
        /* Dividend contract identifies as 700YYYYMMDDHHMM */
        return 700201709192119;
    }

    /* Snapshot to current state of contract*/
    function snapshot() adminOnly {
        // First delete existing holder balances
        uint256 i;
        for (i = 0; i < allTokenHolders.length; i++)
            balances[allTokenHolders[i]] = 0;

        // Now clone our contract to match
        allTokenHolders.length = siftContract.tokenHolderCount();
        for (i = 0; i < allTokenHolders.length; i++) {
            address addr = siftContract.tokenHolder(i);
            allTokenHolders[i] = addr;
            balances[addr] = siftContract.balanceOf(addr);
        }

        // Update
        SnapshotTaken();
    }

    function snapshotUpdate(address _addr, uint256 _newBalance, string _details) adminOnly {
        // Are they already a holder?  If not and no new balance then we're making no change so leave now, or if they are and balance is the same
        uint256 existingBalance = balances[_addr];
        if (existingBalance == _newBalance)
            return;
        
        // So we definitely have a change to make.  If they are not a holder add to our list and update balance.  If they are a holder who maintains balance update balance.  Otherwise set balance to 0 and delete.
        if (existingBalance == 0) {
            // New holder, just add them
            allTokenHolders.length++;
            allTokenHolders[allTokenHolders.length - 1] = _addr;
            balances[_addr] = _newBalance;
        }
        else if (_newBalance > 0) {
            // Existing holder we're updating
            balances[_addr] = _newBalance;
        } else {
            // Existing holder, we're deleting
            balances[_addr] = 0;

            /* Find out where in our array they are */
            uint256 tokenHolderCount = allTokenHolders.length;
            uint256 foundIndex = 0;
            bool found = false;
            uint256 i;
            for (i = 0; i < tokenHolderCount; i++)
                if (allTokenHolders[i] == _addr) {
                    foundIndex = i;
                    found = true;
                    break;
                }
            
            /* We now need to shuffle down the array */
            if (found) {
                for (i = foundIndex; i < tokenHolderCount - 1; i++)
                    allTokenHolders[i] = allTokenHolders[i + 1];
                allTokenHolders.length--;
            }
        }

        // Audit it
        SnapshotUpdated(_addr, existingBalance, _newBalance, _details);
    }

    /* Gets the balance of a specified account */
    function balanceOf(address addr) accountReaderOnly constant returns (uint256) {
        return balances[addr];
    }

    /* Returns the total number of holders of this currency. */
    function tokenHolderCount() accountReaderOnly constant returns (uint256) {
        return allTokenHolders.length;
    }

    /* Gets the token holder at the specified index. */
    function tokenHolder(uint256 _index) accountReaderOnly constant returns (address) {
        return allTokenHolders[_index];
    }
 

}