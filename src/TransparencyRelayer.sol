pragma solidity ^0.4.11;
import "AuthenticationManager.sol";

/* The transparency relayer contract is responsible for keeping an immutable ledger of account balances that can be audited at a later time .*/
contract TransparencyRelayer {
    /* Represents what SIFT administration report the fund as being worth at a snapshot moment in time. */
    struct FundValueRepresentation {
        uint256 usdValue;
        uint256 etherEquivalent;
        uint256 suppliedTimestamp;
        uint256 blockTimestamp;
    }

    /* Represents a published balance of a particular account at a moment in time. */
    struct AccountBalanceRepresentation {
        string accountType; /* Bitcoin, USD, etc. */
        string accountIssuer; /* Kraken, Bank of America, etc. */
        uint256 balance; /* Rounded to appropriate for balance - i.e. full USD or full BTC */
        string accountReference; /* Could be crypto address, bank account number, etc. */
        string validationUrl; /* Some validation URL - i.e. base64 encoded notary */
        uint256 suppliedTimestamp;
        uint256 blockTimestamp;
    }

    /* An array defining all the fund values as supplied by SIFT over the time of the contract. */
    FundValueRepresentation[] public fundValues;
    
    /* An array defining the history of account balances over time. */
    AccountBalanceRepresentation[] public accountBalances;

    /* Defines the admin contract we interface with for credentails. */
    AuthenticationManager authenticationManager;

    /* Fired when the fund value is updated by an administrator. */
    event FundValue(uint256 usdValue, uint256 etherEquivalent, uint256 suppliedTimestamp, uint256 blockTimestamp);

    /* Fired when an account balance is being supplied in some confirmed form for future validation on the blockchain. */
    event AccountBalance(string accountType, string accountIssuer, uint256 balance, string accountReference, string validationUrl, uint256 timestamp, uint256 blockTimestamp);

    /* This modifier allows a method to only be called by current admins */
    modifier adminOnly {
        if (!authenticationManager.isCurrentAdmin(msg.sender)) throw;
        _;
    }

    /* Create our contract and specify the location of other addresses */
    function TransparencyRelayer(address _authenticationManagerAddress) {
        /* Setup access to our other contracts and validate their versions */
        authenticationManager = AuthenticationManager(_authenticationManagerAddress);
        if (authenticationManager.contractVersion() != 100201707071124)
            throw;
    }

    /* Gets the contract version for validation */
    function contractVersion() constant returns(uint256) {
        /* Transparency contract identifies as 200YYYYMMDDHHMM */
        return 200201707071127;
    }

    /* Returns how many fund values are present in the market. */
    function fundValueCount() constant returns (uint256 _count) {
        _count = fundValues.length;
    }

    /* Returns how account balances are present in the market. */
    function accountBalanceCount() constant returns (uint256 _count) {
        _count = accountBalances.length;
    }

    /* Defines the current value of the funds assets in USD and ETHER */
    function fundValuePublish(uint256 _usdTotalFund, uint256 _etherTotalFund, uint256 _definedTimestamp) adminOnly {
        /* Store values */
        fundValues.length++;
        fundValues[fundValues.length - 1] = FundValueRepresentation(_usdTotalFund, _etherTotalFund, _definedTimestamp, now);

        /* Audit this */
        FundValue(_usdTotalFund, _etherTotalFund, _definedTimestamp, now);
    }

    function accountBalancePublish(string _accountType, string _accountIssuer, uint256 _balance, string _accountReference, string _validationUrl, uint256 _timestamp) adminOnly {
        /* Store values */
        accountBalances.length++;
        accountBalances[accountBalances.length - 1] = AccountBalanceRepresentation(_accountType, _accountIssuer, _balance, _accountReference, _validationUrl, _timestamp, now);

        /* Audit this */
        AccountBalance(_accountType, _accountIssuer, _balance, _accountReference, _validationUrl, _timestamp, now);
    }

}