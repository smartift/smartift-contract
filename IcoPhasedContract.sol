pragma solidity ^0.4.11;
import "AdminManagedContract.sol";
import "Erc20Token.sol";

contract IcoPhasedContract is AdminManagedContract, Erc20Token("Smart Investment Fund", "SIFT", 0) {
    /* Defines whether or not we are in the ICO phase */
    bool public icoPhase = true;

    /* Defines whether or not the ICO has been abandoned */
    bool public icoAbandoned = false;
    
    /* Defines the sale price during ICO */
    uint256 constant icoUnitPrice = 10 finney;

    /* If an ICO is abandoned and some withdrawals fail then this map allows people to request withdrawal of locked-in ether. */
    mapping(address => uint256) emergencyFunds;

    /* Defines how many accounts are in the emergency fund map. */
    uint256 emergencyFundCount = 0;

    /* Defines our event fired when the ICO is closed */
    event IcoClosed();

    /* Defines our event fired if the ICO is abandoned */
    event IcoAbandoned(string details);
    
    /* Ensures a function can only be called during the ICO */
    modifier onlyDuringIco {
        if (!icoPhase && !icoAbandoned) throw;
        _;
    }
    /* Ensures a function can only be called after the ICO */
    modifier onlyAfterIco {
        if (icoPhase && !icoAbandoned) throw;
        _;
    }

    /* Close the ICO phase and transition to execution phase */
    function adminIcoClose() adminOnly onlyDuringIco {
        icoPhase = false;
        IcoClosed();
    }
    
    /* Handle receiving ether in ICO phase - we work out how much the user has bought, allocate a suitable balance and send their change */
    function () onlyDuringIco payable {
        /* Determine how much they've actually purhcased and any ether change */
        uint256 tokensPurchased = msg.value / icoUnitPrice;
        uint256 purchaseTotalPrice = tokensPurchased * icoUnitPrice;
        uint256 change = msg.value - purchaseTotalPrice;

        /* Increase their new balance if trhey actually purchased any */
        if (tokensPurchased > 0) {
            bool isNew = balances[msg.sender] < 1;
            balances[msg.sender] += tokensPurchased;
            totalSupplyAmount += tokensPurchased;
            if (isNew)
                tokenOwnerAdd(msg.sender);
            Transfer(0, msg.sender, tokensPurchased);
        }

        /* Send change back to recipient */
        if (change > 0 && !msg.sender.send(change))
            throw;
    }

    /* Abandons the ICO and returns funds to shareholders.  Any failed funds can be separately withdrawn once the ICO is abandoned. */
    function adminIcoAbandon() adminOnly onlyDuringIco {
        /* Work out a refund per share per share */
        uint256 paymentPerShare = this.balance / totalSupplyAmount;

        /* Enum all accounts and send them refund */
        for (uint256 i = 0; i < allTokenHolders.length; i++) {
            /* Calculate how much goes to this shareholder */
            address addr = allTokenHolders[i];
            uint256 etherToSend = paymentPerShare * balances[addr];
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

        // If we haven't failed then self-destruct
        if (emergencyFundCount == 0)
            selfdestruct(adminAudit[0]);
    }

    /* Allows people to withdraw funds that failed to send during the abandonment of the ICO for any reason. */
    function icoEmergencyWithdrawal() {
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

        // Close contract if we now can
        if (emergencyFundCount == 0)
            selfdestruct(adminAudit[0]);
    }
}