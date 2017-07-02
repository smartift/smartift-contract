pragma solidity ^0.4.11;
import "Erc20Token.sol";
import "IcoPhasedContract.sol";
import "MarketplaceToken.sol";

contract SmartInvestmentFund is Erc20Token("Smart Investment Fund", "SIF", 0), IcoPhasedContract, MarketplaceToken(5) {
    /* Sets the shareholder account for auto buyback */
    address buybackShareholderAccount;

    /* Defines the sale price during ICO */
    uint256 constant icoUnitPrice = 10 finney;

    /* Defines how much the fund is worth per share in USD based on last reported price. */
    uint256 public fundValuePerShareUsd;

    /* Defines how much the fund is worth per share in ether based on last reported price. */
    uint256 public fundValuePerShareEther;

    /* Defines how much the fund is worth in total in USD based on last reported price. */
    uint256 public fundValueTotalUsd;

    /* Defines how much the fund is worth in total in ether based on last reported price. */
    uint256 public fundValueTotalEther;

    /* Defines the minimum amount that is considered an "in-range" value for the buyback programme. */
    uint256 buybackMinimumPurchaseAmount;
    
    /* Defines the maximum amount that is considered an "in-range" value for the buyback programme. */
    uint256 buybackMaximumPurchaseAmount;

    /* Fired whenever the shareholder for buyback is changed */
    event BuybackShareholderUpdated(address shareholder);

    /* Fired when funds are added to the buyback fund */
    event BuybackFundIncrease(uint256 amount);

    /* Fired when the fund value is updated by an administrator  */
    event FundValueUpdate(uint256 fundValuePerShareUsd, uint256 fundValuePerShareEther, uint256 fundValueTotalUsd, uint256 fundValueTotalEther);

    /* Fired when the fund is eventually closed. */
    event FundClosed();

    /* Initializes contract and adds creator as an admin user */
    function SmartTradingFund() {
        // Set the first admin to be the person creating the contract
        adminUsers[msg.sender] = true;
        AuditAdminAdded(msg.sender);

        // Set the shareholder to initially be the contract creator
        buybackShareholderAccount = msg.sender;
        BuybackShareholderUpdated(msg.sender);

        // Setup other values
        fundValuePerShareEther = 0;
        fundValuePerShareUsd = 0;
        fundValueTotalEther = 0;
        fundValueTotalUsd = 0;
    }

    /* Handle receiving ether in ICO phase - we work out how much the user has bought, allocate a suitable balance and send their change */
    function () onlyDuringIco payable {
        // Determine how much they've actually purhcased and any ether change
        uint256 tokensPurchased = msg.value / icoUnitPrice;
        uint256 purchaseTotalPrice = tokensPurchased * icoUnitPrice;
        uint256 change = msg.value - purchaseTotalPrice;

        // Increase their new balance if trhey actually purchased any
        if (tokensPurchased > 0) {
            balances[msg.sender] += tokensPurchased;
            _totalSupply += tokensPurchased;
        }

        // Send change back to recipient
        if (change > 0 && !msg.sender.send(change))
                throw;

        // Fire transfer event
        if (tokensPurchased > 0)
            Transfer(0, msg.sender, tokensPurchased);
    }

    /* Update our shareholder account that we send any buyback shares to for holding */
    function buybackShareholderSet(address shareholder) adminOnly {
        buybackShareholderAccount = shareholder;
        BuybackShareholderUpdated(shareholder);
    }

    /* Makes a dividend payment - we send it to all coin holders but we exclude any coins held in the shareholder account as the equivalent dividend is excluded prior to paying in to reduce overall
       transaction fees */
    function dividendPay() payable adminOnly onlyAfterIco {
        // Determine how much coin supply we have minus that held by shareholder
        uint256 validSupply = _totalSupply - balances[buybackShareholderAccount];

        // Work out from this a dividend per share
        uint256 paymentPerShare = msg.value / validSupply;
        uint256 remainder = msg.value - (paymentPerShare * validSupply);

        // Enum all accounts and send them payment
        // TODO: Finish this

        // Rather than sending any rounding errors back we hold for our buyback potentials - add audit for this
        BuybackFundIncrease(remainder);
    }

    /* Adds funds that can be used for buyback purposes and are kept in this wallet until buyback is complete */
    function buybackAddFunds() payable adminOnly onlyAfterIco {
        // Just audit this
        BuybackFundIncrease(msg.value);
    }

    /* Sets minimum and maximum amounts for buyback where 0 indicates no limit */
    function buybackSetLimits(uint256 minimum, uint256 maximum) adminOnly onlyAfterIco {
        // Store values in public variables
        buybackMinimumPurchaseAmount = minimum;
        buybackMaximumPurchaseAmount = maximum;
    }

    /* Defines the current value of the funds assets in USD and ETHER */
    function fundValueSet(uint256 _usdTotalFund, uint256 _etherTotalFund) adminOnly onlyAfterIco {
        // Store values
        fundValueTotalUsd = _usdTotalFund;
        fundValueTotalEther = _etherTotalFund;
        fundValuePerShareUsd = _usdTotalFund / _totalSupply;
        fundValuePerShareEther = _etherTotalFund / _totalSupply;

        // Audit this
        FundValueUpdate(fundValuePerShareUsd, fundValuePerShareEther, fundValueTotalUsd, fundValueTotalEther);
    }

    /* Closes the fund down - this can only happen if the fund has bought back 90% of the shareholding and is designed to be supported by payout of ether matching value to remaining shareholders outside of
       the contract. */
    function closeFund() adminOnly onlyAfterIco {
        // Ensure the shareholder owns required amount of fund
        uint256 requiredAmount = (_totalSupply * 100) / 90;
        if (balances[buybackShareholderAccount] < requiredAmount)
            throw;
        
        // That's it then, audit and shutdown
        FundClosed();
        selfdestruct(buybackShareholderAccount);
    }

    function buybackProcessOrderBook() private {
        // TODO: Process orders within min/max permitted range if we have ether and if so buy back what we can and send to shareholder
    }
}