pragma solidity ^0.4.11;
import "SmartInvestmentFundToken.sol";

contract DividendManager {
    /* Our handle to the SIFT contract. */
    SmartInvestmentFundToken siftContract;

    /* Handle payments we couldn't make. */
    mapping (address => uint256) public dividends;

    /* Indicates a payment is now available to a shareholder */
    event PaymentAvailable(address addr, uint256 amount);

    /* Indicates a dividend payment was made. */
    event DividendPayment(uint256 paymentPerShare, uint256 timestamp);

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

        /* Determine how much to pay each shareholder. */
        uint256 validSupply = siftContract.totalSupply();
        uint256 paymentPerShare = msg.value / validSupply;
        if (paymentPerShare == 0)
            throw;

        /* Enum all accounts and send them payment */
        uint256 totalPaidOut = 0;
        for (uint256 i = 0; i < siftContract.tokenHolderCount(); i++) {
            address addr = siftContract.tokenHolder(i);
            uint256 dividend = paymentPerShare * siftContract.balanceOf(addr);
            dividends[addr] += dividend;
            PaymentAvailable(addr, dividend);
            totalPaidOut += dividend;
        }

        // Attempt to send change
        uint256 remainder = msg.value - totalPaidOut;
        if (remainder > 0 && !msg.sender.send(remainder)) {
            dividends[msg.sender] += remainder;
            PaymentAvailable(msg.sender, remainder);
        }

        /* Audit this */
        DividendPayment(paymentPerShare, now);
    }
}