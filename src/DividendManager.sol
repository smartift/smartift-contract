pragma solidity ^0.4.11;
import "SmartInvestmentFundToken.sol";

contract DividendManager {
    /* Our handle to the SIFT contract. */
    SmartInvestmentFundToken siftContract;

    /* Indicates a dividend payment was made */
    event Payment(uint256 etherPerShare, uint256 totalPaidOut);

    /* Create our contract with references to other contracts as required. */
    function DividendManager(address _siftContractAddress) {
        /* Setup access to our other contracts and validate their versions */
        siftContract = SmartInvestmentFundToken(_siftContractAddress);
        if (siftContract.contractVersion() != 500201707071147)
            throw;
    }

    /* Gets the contract version for validation */
    function contractVersion() constant returns(uint256) {
        /* Dividend contract identifies as 600YYYYMMDDHHMM */
        return 600201707071502;
    }

    /* Makes a dividend payment - we send it to all coin holders but we exclude any coins held in the shareholder account as the equivalent dividend is excluded prior to paying in to reduce overall
       transaction fees */
    function () payable {
        if (siftContract.isClosed())
            throw;

        /* Determine how much coin supply we have. */
        uint256 validSupply = siftContract.totalSupply();

        /* Work out from this a dividend per share */
        uint256 paymentPerShare = msg.value / validSupply;
        //uint256 remainder = msg.value - (paymentPerShare * validSupply);

        /* Enum all accounts and send them payment */
        uint256 totalPaidOut = 0;
        for (uint256 i = 0; i < siftContract.tokenHolderCount(); i++) {
            /* Calculate how much goes to this shareholder */
            address addr = siftContract.tokenHolder(i);
            uint256 etherToSend = paymentPerShare * siftContract.balanceOf(addr);
            if (etherToSend < 1)
                continue;
            totalPaidOut += etherToSend;

            /* Now let's send them the money */
            if (!addr.send(etherToSend))
                throw;
        }

        /* Audit this */
        Payment(paymentPerShare, totalPaidOut);
    }
}