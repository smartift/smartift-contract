pragma solidity ^0.4.11;
import "AuthenticationManager.sol";
import "SmartInvestmentFundToken.sol";
import "SafeMath.sol";

contract IcoPhaseManagement {
    using SafeMath for uint256;
    
    /* Defines whether or not we are in the ICO phase */
    bool public icoPhase = true;

    /* Defines whether or not the ICO has been abandoned */
    bool public icoAbandoned = false;

    /* Defines whether or not the SIFT contract address has yet been set.  */
    bool siftContractDefined = false;
    
    /* Defines the sale price during ICO */
    uint256 constant icoUnitPrice = 10 finney;

    /* If an ICO is abandoned and some withdrawals fail then this map allows people to request withdrawal of locked-in ether. */
    mapping(address => uint256) public abandonedIcoBalances;

    /* Defines our interface to the SIFT contract. */
    SmartInvestmentFundToken smartInvestmentFundToken;

    /* Defines the admin contract we interface with for credentails. */
    AuthenticationManager authenticationManager;

    /* Defines our event fired when the ICO is closed */
    event IcoClosed();

    /* Defines our event fired if the ICO is abandoned */
    event IcoAbandoned(string details);
    
    /* Ensures that once the ICO is over this contract cannot be used until the point it is destructed. */
    modifier onlyDuringIco {
        bool contractValid = siftContractDefined && !smartInvestmentFundToken.isClosed();
        if (!contractValid || (!icoPhase && !icoAbandoned)) throw;
        _;
    }

    /* This modifier allows a method to only be called by current admins */
    modifier adminOnly {
        if (!authenticationManager.isCurrentAdmin(msg.sender)) throw;
        _;
    }

    /* Create the ICO phase managerment and define the address of the main SIFT contract. */
    function IcoPhaseManagement(address _authenticationManagerAddress) {
        /* Setup access to our other contracts and validate their versions */
        authenticationManager = AuthenticationManager(_authenticationManagerAddress);
        if (authenticationManager.contractVersion() != 100201707171503)
            throw;
    }

    /* Set the SIFT contract address as a one-time operation.  This happens after all the contracts are created and no
       other functionality can be used until this is set. */
    function setSiftContractAddress(address _siftContractAddress) adminOnly {
        /* This can only happen once in the lifetime of this contract */
        if (siftContractDefined)
            throw;

        /* Setup access to our other contracts and validate their versions */
        smartInvestmentFundToken = SmartInvestmentFundToken(_siftContractAddress);
        if (smartInvestmentFundToken.contractVersion() != 500201707171440)
            throw;
        siftContractDefined = true;
    }

    /* Gets the contract version for validation */
    function contractVersion() constant returns(uint256) {
        /* ICO contract identifies as 300YYYYMMDDHHMM */
        return 300201707171440;
    }

    /* Close the ICO phase and transition to execution phase */
    function close() adminOnly onlyDuringIco {
        // Close the ICO
        icoPhase = false;
        IcoClosed();

        // Withdraw funds to the caller
        if (!msg.sender.send(this.balance))
            throw;
    }
    
    /* Handle receiving ether in ICO phase - we work out how much the user has bought, allocate a suitable balance and send their change */
    function () onlyDuringIco payable {
        /* Determine how much they've actually purhcased and any ether change */
        uint256 tokensPurchased = msg.value / icoUnitPrice;
        uint256 purchaseTotalPrice = tokensPurchased * icoUnitPrice;
        uint256 change = msg.value.sub(purchaseTotalPrice);

        /* Increase their new balance if they actually purchased any */
        if (tokensPurchased > 0)
            smartInvestmentFundToken.mintTokens(msg.sender, tokensPurchased);

        /* Send change back to recipient */
        if (change > 0 && !msg.sender.send(change))
            throw;
    }

    /* Abandons the ICO and returns funds to shareholders.  Any failed funds can be separately withdrawn once the ICO is abandoned. */
    function abandon(string details) adminOnly onlyDuringIco {
        /* If already abandoned throw an error */
        if (icoAbandoned)
            throw;

        /* Work out a refund per share per share */
        uint256 paymentPerShare = this.balance / smartInvestmentFundToken.totalSupply();

        /* Enum all accounts and send them refund */
        uint numberTokenHolders = smartInvestmentFundToken.tokenHolderCount();
        uint256 totalAbandoned = 0;
        for (uint256 i = 0; i < numberTokenHolders; i++) {
            /* Calculate how much goes to this shareholder */
            address addr = smartInvestmentFundToken.tokenHolder(i);
            uint256 etherToSend = paymentPerShare * smartInvestmentFundToken.balanceOf(addr);
            if (etherToSend < 1)
                continue;

            /* Allocate appropriate amount of fund to them */
            abandonedIcoBalances[addr] = abandonedIcoBalances[addr].add(etherToSend);
            totalAbandoned = totalAbandoned.add(etherToSend);
        }

        /* Audit the abandonment */
        icoAbandoned = true;
        IcoAbandoned(details);

        // There should be no money left, but withdraw just incase for manual resolution
        uint256 remainder = this.balance.sub(totalAbandoned);
        if (remainder > 0)
            if (!msg.sender.send(remainder))
                // Add this to the callers balance for emergency refunds
                abandonedIcoBalances[msg.sender] = abandonedIcoBalances[msg.sender].add(remainder);
    }

    /* Allows people to withdraw funds that failed to send during the abandonment of the ICO for any reason. */
    function abandonedFundWithdrawal() {
        // This functionality only exists if an ICO was abandoned
        if (!icoAbandoned || abandonedIcoBalances[msg.sender] == 0)
            throw;
        
        // Attempt to send them to funds
        uint256 funds = abandonedIcoBalances[msg.sender];
        abandonedIcoBalances[msg.sender] = 0;
        if (!msg.sender.send(funds))
            throw;
    }
}