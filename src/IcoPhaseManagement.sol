pragma solidity ^0.4.11;
import "AuthenticationManager.sol";
import "SmartInvestmentFundToken.sol";

contract IcoPhaseManagement {
    /* Defines whether or not we are in the ICO phase */
    bool public icoPhase = true;

    /* Defines whether or not the ICO has been abandoned */
    bool public icoAbandoned = false;

    /* Defines whether or not the SIFT contract address has yet been set.  */
    bool siftContractDefined = false;
    
    /* Defines the sale price during ICO */
    uint256 constant icoUnitPrice = 10 finney;

    /* If an ICO is abandoned and some withdrawals fail then this map allows people to request withdrawal of locked-in ether. */
    mapping(address => uint256) emergencyFunds;

    /* Defines how many accounts are in the emergency fund map. */
    uint256 emergencyFundCount = 0;

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
        if (authenticationManager.contractVersion() != 100201707071124)
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
        if (smartInvestmentFundToken.contractVersion() != 500201707071147)
            throw;
        siftContractDefined = true;
    }

    /* Gets the contract version for validation */
    function contractVersion() constant returns(uint256) {
        /* ICO contract identifies as 300YYYYMMDDHHMM */
        return 300201707071208;
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
        uint256 change = msg.value - purchaseTotalPrice;

        /* Increase their new balance if they actually purchased any */
        if (tokensPurchased > 0)
            smartInvestmentFundToken.mintTokens(msg.sender, tokensPurchased);

        /* Send change back to recipient */
        if (change > 0 && !msg.sender.send(change))
            throw;
    }

    /* Abandons the ICO and returns funds to shareholders.  Any failed funds can be separately withdrawn once the ICO is abandoned. */
    function abandon() adminOnly onlyDuringIco {
        /* Work out a refund per share per share */
        uint256 paymentPerShare = this.balance / smartInvestmentFundToken.totalSupply();

        /* Enum all accounts and send them refund */
        uint numberTokenHolders = smartInvestmentFundToken.tokenHolderCount();
        for (uint256 i = 0; i < numberTokenHolders; i++) {
            /* Calculate how much goes to this shareholder */
            address addr = smartInvestmentFundToken.tokenHolder(i);
            uint256 etherToSend = paymentPerShare * smartInvestmentFundToken.balanceOf(addr);
            if (etherToSend < 1)
                continue;

            /* Now let's send them the money */
            if (addr.send(etherToSend)) {
                // We don't let a failed payment stop us - this could somehow prevent fund shutdown and lock everyone's funds in, instead we set up for withdrawal request mechanism
                emergencyFunds[addr] = etherToSend;
                emergencyFundCount++;
            }
        }

        // Audit the abandonment
        icoAbandoned = true;
        IcoAbandoned(emergencyFundCount == 0 ? "Fund shut down after full refunds" : "Some refunds failed, emergency withdrawal is now open");

        // There should be no money left, but withdraw just incase for manual resolution
        if (emergencyFundCount == 0 && this.balance > 0)
            if (!msg.sender.send(this.balance)) {
                // Add this to the callers balance for emergency refunds
                if (emergencyFunds[msg.sender] == 0)
                    emergencyFunds[msg.sender] += this.balance;
                else {
                    emergencyFunds[msg.sender] = this.balance;
                    emergencyFundCount++;
                }
            }
    }

    /* Allows people to withdraw funds that failed to send during the abandonment of the ICO for any reason. */
    function emergencyWithdrawal() {
        // This functionality only exists if an ICO was abandoned
        if (!icoAbandoned || emergencyFundCount == 0)
            throw;
        
        // See how much we owe and if nothing, throw
        if (emergencyFunds[msg.sender] == 0)
            throw;
        uint256 funds = emergencyFunds[msg.sender];
        emergencyFunds[msg.sender] = 0;
        emergencyFundCount--;
        if (!msg.sender.send(funds))
            throw;

        // Signify full shutdown if appropriate
        if (emergencyFundCount == 0) {
            IcoAbandoned("Fund shut down after full refunds");

            // If we're finished there should be no funds left, if there are then we have an issue to manually resolve rather than trapping in the contract
            if (this.balance > 0)
                if (!msg.sender.send(this.balance)) {
                    // No choice left here but to do a self destruct to obtain the funds
                    selfdestruct(msg.sender);
                }
        }
    }
}