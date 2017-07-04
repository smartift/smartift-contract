pragma solidity ^0.4.11;
import "Erc20Token.sol";
import "IcoPhasedContract.sol";
import "MarketplaceToken.sol";

contract SmartInvestmentFund is MarketplaceToken(5) {
    /* Sets the shareholder account for auto buyback */
    address buybackShareholderAccount;

    /* Defines how much the fund is worth in total in USD based on last reported price. */
    uint256 public fundValueTotalUsd;

    /* Defines how much the fund is worth in total in ether based on last reported price. */
    uint256 public fundValueTotalEther;

    /* Defines the minimum amount that is considered an "in-range" value for the buyback programme. */
    uint256 buybackMinimumPurchaseAmount;
    
    /* Defines the maximum amount that is considered an "in-range" value for the buyback programme. */
    uint256 buybackMaximumPurchaseAmount;

    /* Defines the current amount available in the buyback fund. */
    uint256 public buybackFundAmount;

    /* Fired whenever the shareholder for buyback is changed */
    event BuybackShareholderUpdated(address shareholder);

    /* Fired when the fund value is updated by an administrator  */
    event FundValueUpdate(uint256 fundValueTotalUsd, uint256 fundValueTotalEther);

    /* Fired when the fund is eventually closed. */
    event FundClosed();

    /* Indicates a dividend payment was made */
    event DividendPayment(uint256 etherPerShare, uint256 totalPaidOut);

    /* Initializes contract and adds creator as an admin user */
    function SmartInvestmentFund() {
        /* Set the first admin to be the person creating the contract */
        adminUsers[msg.sender] = true;
        AdminAdded(msg.sender);
        adminAudit.length++;
        adminAudit[adminAudit.length - 1] = msg.sender;

        /* Set the shareholder to initially be the contract creator */
        buybackShareholderAccount = msg.sender;
        BuybackShareholderUpdated(msg.sender);

        /* Setup other values */
        fundValueTotalEther = 0;
        fundValueTotalUsd = 0;
    }

    /* Update our shareholder account that we send any buyback shares to for holding */
    function adminBuybackShareholderSet(address shareholder) adminOnly {
        buybackShareholderAccount = shareholder;
        BuybackShareholderUpdated(shareholder);
    }

    /* Makes a dividend payment - we send it to all coin holders but we exclude any coins held in the shareholder account as the equivalent dividend is excluded prior to paying in to reduce overall
       transaction fees */
    function adminDividendPay() payable adminOnly onlyAfterIco {
        /* Determine how much coin supply we have minus that held by shareholder */
        uint256 validSupply = totalSupplyAmount - balances[buybackShareholderAccount];

        /* Work out from this a dividend per share */
        uint256 paymentPerShare = msg.value / validSupply;
        uint256 remainder = msg.value - (paymentPerShare * validSupply);

        /* Enum all accounts and send them payment */
        uint256 totalPaidOut = 0;
        for (uint256 i = 0; i < allTokenHolders.length; i++) {
            /* Calculate how much goes to this shareholder */
            address addr = allTokenHolders[i];
            uint256 etherToSend = paymentPerShare * balances[addr];
            if (etherToSend < 1)
                continue;
            totalPaidOut += etherToSend;

            /* Now let's send them the money */
            if (!addr.send(etherToSend))
                throw;
        }

        /* Audit this */
        DividendPayment(paymentPerShare, totalPaidOut);

        /* Rather than sending any rounding errors back we hold for our buyback potentials - add audit for this */
        buybackFundAmount += remainder;
    }

    /* Adds funds that can be used for buyback purposes and are kept in this wallet until buyback is complete */
    function adminBuybackAddFunds() payable adminOnly {
        /* Audit this and increase the amount we have allocated to buyback */
        buybackFundAmount += msg.value;
    }

    /* Sets minimum and maximum amounts for buyback where 0 indicates no limit */
    function adminBuybackSetLimits(uint256 minimum, uint256 maximum) adminOnly {
        /* Store values in public variables */
        buybackMinimumPurchaseAmount = minimum;
        buybackMaximumPurchaseAmount = maximum;
    }

    /* Defines the current value of the funds assets in USD and ETHER */
    function adminFundValueSet(uint256 _usdTotalFund, uint256 _etherTotalFund) adminOnly {
        /* Store values */
        fundValueTotalUsd = _usdTotalFund;
        fundValueTotalEther = _etherTotalFund;

        /* Audit this */
        FundValueUpdate(fundValueTotalUsd, fundValueTotalEther);
    }

    /* Closes the fund down - this can only happen if the fund has bought back 90% of the shareholding and is designed to be supported by payout of ether matching value to remaining shareholders outside of
       the contract. */
    function adminCloseFund() adminOnly onlyAfterIco {
        /* Ensure the shareholder owns required amount of fund */
        uint256 requiredAmount = (totalSupplyAmount * 100) / 90;
        if (balances[buybackShareholderAccount] < requiredAmount)
            throw;
        
        /* That's it then, audit and shutdown */
        FundClosed();
        selfdestruct(buybackShareholderAccount);
    }

    /* When the marketplace could not fulfil a new sell order we have the chance to do so here using the buyback fund with as much as is available */
    function marketplaceUnfulfilledSellOrder(uint256 sellOrderIndex) private {
        /* Skip if no buyback fund left */
        if (buybackFundAmount < 1)
            return;

        /* Check this sell orders price - is it within our buy/sell range? */
        Order sellOrder = sellOrders[sellOrderIndex];
        if (buybackMinimumPurchaseAmount > 0 && sellOrder.price < buybackMinimumPurchaseAmount)
            throw;
        if (buybackMaximumPurchaseAmount > 0 && sellOrder.price > buybackMaximumPurchaseAmount)
            throw;

        /* Can we afford any shares at this price? */
        uint256 amountToPurchase = buybackFundAmount / sellOrder.price;
        if (amountToPurchase < 1)
            return;
        if (amountToPurchase > sellOrder.quantityRemaining)
            amountToPurchase = sellOrder.quantityRemaining;
        
        /* Great we can buy some - so let's do it! */
        if (balances[buybackShareholderAccount] == 0)
            tokenOwnerAdd(buybackShareholderAccount);
        balances[buybackShareholderAccount] += amountToPurchase;
        balances[sellOrder.account] -= amountToPurchase;
        if (balances[sellOrder.account] < 1)
            tokenOwnerRemove(sellOrder.account);
        Transfer(sellOrder.account, buybackShareholderAccount, amountToPurchase);

        /* Now adjust their order */
        sellOrders[sellOrderIndex].quantityRemaining -= amountToPurchase;
        MarketplaceOrderUpdated("Sell", sellOrder.id, sellOrder.price, sellOrders[sellOrderIndex].quantityRemaining);

        /* Finally lets send some ether to the seller minus fees */
        uint256 costToBuy = amountToPurchase * sellOrder.price;
        uint256 transactionCost = costToBuy / 1000 * feePercentageOneDp;
        uint256 amountToSeller = costToBuy - transactionCost;
        if (!sellOrder.account.send(amountToSeller))
            throw;
        buybackFundAmount -= amountToSeller;
        marketplaceTransactionCostAvailable(transactionCost);
    }

    /* Handle the transaction fee from a sell order being available to the contract. */
    function marketplaceTransactionCostAvailable(uint256 amount) private {
        buybackFundAmount += amount;
    }

    /* Bugs
        Can sell more than you own (when creating sell order - no checks happen)
        Prefix all admin methods with adminOnly
        Buy/BuyCancel failing
        Buyback fund overlaps?
        Dividends are being sent to buybackShareholderAccount
        Doesnt send out wei when close ICO called
        Can't close fund - total supply = 0?
    */
}