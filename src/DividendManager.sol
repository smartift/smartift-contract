pragma solidity ^0.4.11;
import "SmartInvestmentFundToken.sol";
import "SafeMath.sol";

contract DividendManager {
    using SafeMath for uint256;

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
        if (siftContract.contractVersion() != 500201707171440)
            throw;
    }

    /* Gets the contract version for validation */
    function contractVersion() constant returns(uint256) {
        /* Dividend contract identifies as 600YYYYMMDDHHMM */
        return 600201707171440;
    }

    /* Makes a dividend payment - we make it available to all senders then send the change back to the caller.  We don't actually send the payments to everyone to reduce gas cost and also to 
       prevent potentially getting into a situation where we have recipients throwing causing dividend failures and having to consolidate their dividends in a separate process. */
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
            dividends[addr] = dividends[addr].add(dividend);
            PaymentAvailable(addr, dividend);
            totalPaidOut = totalPaidOut.add(dividend);
        }

        // Attempt to send change
        uint256 remainder = msg.value.sub(totalPaidOut);
        if (remainder > 0 && !msg.sender.send(remainder)) {
            dividends[msg.sender] = dividends[msg.sender].add(remainder);
            PaymentAvailable(msg.sender, remainder);
        }

        /* Audit this */
        DividendPayment(paymentPerShare, now);
    }

    /* Allows a user to request a withdrawal of their dividend in full. */
    function withdrawDividend() {
        // Ensure we have dividends available
        if (dividends[msg.sender] == 0)
            throw;
        
        // Determine how much we're sending and reset the count
        uint256 dividend = dividends[msg.sender];
        dividends[msg.sender] = 0;

        // Attempt to withdraw
        if (!msg.sender.send(dividend))
            throw;
    }
}