pragma solidity ^0.4.11;
import "AuthenticationManager.sol";
import "SmartInvestmentFundToken.sol";

contract Marketplace {
    /* Defines an order in our marketplace */
    struct Order {
        uint256 id;
        uint256 price;
        uint256 quantityRemaining;
        uint256 quantityStart;
        address account;
        uint256 amountLoaded;  /* Only useful for buy orders */
        uint256 amountSpent; /* Only useful for buy orders */
    }

    /* Defines the admin contract we interface with for credentails. */
    AuthenticationManager authenticationManager;

    /* Defines our interface to the SIFT contract. */
    SmartInvestmentFundToken smartInvestmentFundToken;

    /* Defines the address of our sift contract. */
    address siftContractAddress = 0;

    /* The percentage fee to take for any SELL transactions in ether.  This is based to one DP so 1 = 0.1%, 10 = 1% and 1000 = 100%. */
    uint256 feePercentageOneDp = 5;

    /* Defines the ID of the next order (buy or sell) that we will create. */
    uint256 nextOrderId = 1;

    /* Defines if the marketplace is currently closed */
    bool isClosed = true;

    /* Defines a map allowing people to withdraw funds if a market was closed and repayment failed */
    mapping (address => uint256) failedWithdrawRequests;

    /* Defines all the sell orders in the system */
    Order[] public sellOrders;

    /* Defines all the buy orders in the system */
    Order[] public buyOrders;

    /* Defines the current amount available in the buyback fund. */
    uint256 public buybackFundAmount;

    /* Sets the shareholder account for auto buyback */
    address public buybackShareholderAccount;

    /* Defines the minimum amount that is considered an "in-range" value for the buyback programme. */
    uint256 buybackMinimumPurchaseAmount;
    
    /* Defines the maximum amount that is considered an "in-range" value for the buyback programme. */
    uint256 buybackMaximumPurchaseAmount;

    /* Announces an order is opened */
    event OrderOpened(string orderType, uint256 id, uint256 price, uint256 quantity);

    /* Announces an order is updated */
    event OrderUpdated(string orderType, uint256 id, uint256 price, uint256 quantity);

    /* Announce an order has been closed */
    event OrderClosed(string orderType, uint256 id);

    /* Announce that an admin closed all orders for some reason */
    event MarketClosed(string details);

    /* Announces that the marketplace has been opened. */
    event MarketOpened();

    /* Announces funds have been added to the buyback fund */
    event BuybackFundsAdded(uint256 amount, uint256 newBalance, string source);

    /* Announces funds have been removed from the buyback fund */
    event BuybackFundsRemoved(uint256 amount, uint256 newBalance, string destination);
    
    /* This modifier allows a method to only be called by current admins */
    modifier adminOnly {
        if (!authenticationManager.isCurrentAdmin(msg.sender)) throw;
        _;
    }

    /* This modifier ensures that the contract is initialised and we have access to the SIFT contract. */
    modifier contractInitialised {
        if (siftContractAddress != 0) throw;
        _;
    }

    /* Create a new instance of this contract and connect to other requisite contracts and validate their versions. */
    function MarketplaceToken(address _authenticationManagerAddress, address _buybackShareholder) {
        /* Setup access to our other contracts and validate their versions */
        authenticationManager = AuthenticationManager(_authenticationManagerAddress);
        if (authenticationManager.contractVersion() != 100201707071124)
            throw;
        
        /* Store our buyback shareholedr */
        if (_buybackShareholder == 0)
            throw;
        buybackShareholderAccount = _buybackShareholder;
    }

    /* Set the SIFT contract address as a one-time operation.  This happens after all the contracts are created and no
       other functionality can be used until this is set. */
    function setSiftContractAddress(address _siftContractAddress) {
        /* This can only happen once in the lifetime of this contract */
        if (siftContractAddress != 0)
            throw;

        /* Setup access to our other contracts and validate their versions */
        smartInvestmentFundToken = SmartInvestmentFundToken(_siftContractAddress);
        if (smartInvestmentFundToken.contractVersion() != 500201707071147)
            throw;
        siftContractAddress = siftContractAddress;
        MarketOpened();
    }

    /* Gets the contract version for validation */
    function contractVersion() constant returns(uint256) {
        /* Marketplace contract identifies as 400YYYYMMDDHHMM */
        return 400201707071240;
    }

    /* Adds a sell order to the system.  It will follow normal consolidation method. */
    function sell(uint256 _price, uint256 _quantity) contractInitialised returns(uint256 _numberSold, uint256 _id) {
        /* If we're closed, throw */
        if (isClosed || smartInvestmentFundToken.isClosed())
            throw;

        /* Add the order */
        sellOrders.length++;
        sellOrders[sellOrders.length - 1] = Order(nextOrderId, _price, _quantity, _quantity, msg.sender, 0, 0);

        /* Audit the creation */
        OrderOpened("Sell", nextOrderId, _price, _quantity);

        /* Consolidate this sell order against the books */
        consolidateSell();

        /* Do we have any remaining to purchase?  If so let's use our buybackProcessOrderBook() */
        if (sellOrders[sellOrders.length - 1].quantityRemaining > 0)
            buybackProcess(sellOrders.length - 1);

        /* Determine our return values */
        _numberSold = _quantity - sellOrders[sellOrders.length - 1].quantityRemaining;
        _id  = nextOrderId;
        nextOrderId++;

        /* Tidy up the sell / buy orders lists now we've extract the data we care about */
        tidyArrays();
    }

    /* Actually take most recent sell order and sell it for highest price possible - this is a separate function due to stack issues in Solidity */
    function consolidateSell() private {
        /* Do an initial sift to determine the highest price that is within our price range in the stack */
        uint256 highestPrice = 0;
        bool validPricesExist = false;
        uint256 buyIndex;
        Order sellOrder = sellOrders[sellOrders.length - 1];
        for (buyIndex = 0; buyIndex < buyOrders.length; buyIndex++)
            if (buyOrders[buyIndex].quantityRemaining > 0 && buyOrders[buyIndex].price >= sellOrder.price && (!validPricesExist || buyOrders[buyIndex].price > highestPrice)) {
                highestPrice = buyOrders[buyIndex].price;
                validPricesExist = true;
            }
        
        /* As long as other cheap prices still exist, keep looping and closing for this price */
        while (validPricesExist) {
            /* In this loop we do two things - firstly if the order is at loopPrice, we sell up to theirs and our maximum quantity.  Secondly we look for the next-highest price. */
            uint256 loopPrice = highestPrice;
            validPricesExist = false;
            for (buyIndex = 0; buyIndex < buyOrders.length; buyIndex++) {
                /* First - if the price of this particular order is at the price we're looking for - we can trade and then re-loop */
                Order buyOrder = buyOrders[buyIndex];
                if (buyOrder.price == loopPrice && buyOrder.quantityRemaining > 0) {
                    /* Decide how many we want to buy */
                    uint256 numberToBuy = sellOrder.quantityRemaining > buyOrder.quantityRemaining ? buyOrder.quantityRemaining : sellOrder.quantityRemaining;
                    uint256 costToBuy = numberToBuy * buyOrder.price;
                    if (costToBuy + buyOrder.amountSpent > buyOrder.amountLoaded)
                        /* If this somehow happens it is a bug but we cannot allow spending money that isn't there */
                        throw;

                    /* Update the orders respectively including audit */
                    buyOrders[buyIndex].quantityRemaining -= numberToBuy;
                    buyOrders[buyIndex].amountSpent += costToBuy;
                    sellOrder.quantityRemaining -= numberToBuy;
                    OrderUpdated("Buy", buyOrder.id, buyOrder.price, buyOrders[buyIndex].quantityRemaining);
                    OrderUpdated("Sell", sellOrder.id, sellOrder.price, sellOrder.quantityRemaining);

                    /* Transfer tokens from sell order account to buy order account - include a Transfer() here and update the token recipient lists */
                    smartInvestmentFundToken.transferShares(sellOrder.account, buyOrder.account, numberToBuy);

                    /* Send ether to person with sell order */
                    uint256 transactionCost = costToBuy / 1000 * feePercentageOneDp;
                    uint256 amountToSeller = costToBuy - transactionCost;
                    if (!sellOrder.account.send(amountToSeller))
                        throw;
                    buybackFundAmount += transactionCost;
                    BuybackFundsAdded(transactionCost, buybackFundAmount, "Marketplace Fee");

                    /* If nothing remaining to sell, we can stop here */
                    if (sellOrder.quantityRemaining < 1)
                        break;

                    /* Loop for next one */
                    continue;
                }

                /* Second - if we're still here the question is will this become the new cheapest price? */
                if (buyOrder.price < loopPrice && buyOrder.quantityRemaining > 0 && buyOrder.price >= sellOrder.price && (!validPricesExist || buyOrder.price > highestPrice)) {
                    highestPrice = buyOrders[buyIndex].price;
                    validPricesExist = true;
                }
            }

            /* If the buy order is closed, we can stop looking */
            if (buyOrder.quantityRemaining < 1)
                break;
        }
    }

    /* Adds a buy order to the system.  It will follow normal consolidation method. */
    function buy(uint256 _price, uint256 _quantity) contractInitialised payable returns(uint256 _numberPurchased, uint256 _id) {
        /* If we're closed, throw */
        if (isClosed || smartInvestmentFundToken.isClosed())
            throw;

        /* Ensure correct value was sent with the buy - we store the ether */
        if (msg.value != _quantity * _price)
            throw;

        /* Create the order */
        buyOrders.length++;
        buyOrders[buyOrders.length - 1] = Order(nextOrderId, _price, _quantity, _quantity, msg.sender, msg.value, 0);

        /* Audit the creation */
        OrderOpened("Buy", nextOrderId, _price, _quantity);

        /* Consolidate any sell orders against this buy order */
        consolidateBuy();        

        /* Determine our return values */
        _numberPurchased = _quantity - buyOrders[buyOrders.length - 1].quantityRemaining;
        _id  = nextOrderId;
        nextOrderId++;

        /* Tidy up the sell / buy orders lists now we've extract the data we care about */
        tidyArrays();
    }

    /* Actually take most recent buy order and buy for lowest price possible - this is a separate function due to stack issues in Solidity */
    function consolidateBuy() private {
        /* Do an initial sift to determine the lowest price that is within our price range in the stack */
        uint256 cheapestPrice = 0;
        bool validPricesExist = false;
        uint256 sellIndex;
        Order buyOrder = buyOrders[buyOrders.length - 1];
        for (sellIndex = 0; sellIndex < sellOrders.length; sellIndex++)
            if (sellOrders[sellIndex].quantityRemaining > 0 && sellOrders[sellIndex].price <= buyOrder.price && (!validPricesExist || sellOrders[sellIndex].price < cheapestPrice)) {
                cheapestPrice = sellOrders[sellIndex].price;
                validPricesExist = true;
            }

        /* As long as other cheap prices still exist, keep looping and closing for this price */
        while (validPricesExist) {
            /* In this loop we do two things - firstly if the order is at loopPrice, we buy up to theirs and our maximum quantity.  Secondly we look for the next-cheapest price. */
            uint256 loopPrice = cheapestPrice;
            validPricesExist = false;
            for (sellIndex = 0; sellIndex < sellOrders.length; sellIndex++) {
                /* First - if the price of this particular order is at the price we're looking for - we can trade and then re-loop */
                Order sellOrder = sellOrders[sellIndex];
                if (sellOrder.price == loopPrice && sellOrder.quantityRemaining > 0) {
                    /* Decide how many we want to buy */
                    uint256 numberToBuy = buyOrder.quantityRemaining > sellOrder.quantityRemaining ? sellOrder.quantityRemaining : buyOrder.quantityRemaining;
                    uint256 costToBuy = numberToBuy * sellOrder.price;
                    if (costToBuy + buyOrder.amountSpent > buyOrder.amountLoaded)
                        /* If this somehow happens it is a bug but we cannot allow spending money that isn't there */
                        throw;

                    /* Update the orders respectively including audit */
                    sellOrders[sellIndex].quantityRemaining -= numberToBuy;
                    buyOrder.quantityRemaining -= numberToBuy;
                    buyOrder.amountSpent += costToBuy;
                    OrderUpdated("Buy", buyOrder.id, buyOrder.price, buyOrder.quantityRemaining);
                    OrderUpdated("Sell", sellOrder.id, sellOrder.price, sellOrders[sellIndex].quantityRemaining);

                    /* Transfer tokens from sell order account to buy order account - include a Transfer() here and update the token recipient lists */
                    smartInvestmentFundToken.transferShares(sellOrder.account, buyOrder.account, numberToBuy);

                    /* Send ether to person with sell order */
                    uint256 transactionCost = costToBuy / 1000 * feePercentageOneDp;
                    uint256 amountToSeller = costToBuy - transactionCost;
                    if (!sellOrder.account.send(amountToSeller))
                        throw;
                    buybackFundAmount += transactionCost;
                    BuybackFundsAdded(transactionCost, buybackFundAmount, "Marketplace Fee");

                    /* If nothing remaining to buy, we can stop here */
                    if (buyOrder.quantityRemaining < 1)
                        break;

                    /* Loop for next one */
                    continue;
                }

                /* Second - if we're still here the question is will this become the new cheapest price? */
                if (sellOrder.price > loopPrice && sellOrder.quantityRemaining > 0 && sellOrder.price <= buyOrder.price && (!validPricesExist || sellOrder.price < cheapestPrice)) {
                    cheapestPrice = sellOrders[sellIndex].price;
                    validPricesExist = true;
                }
            }

            /* If the buy order is closed, we can stop looking */
            if (buyOrder.quantityRemaining < 1)
                break;
        }
    }

    /* Cancels the specified sell order if it is still valid and owned by the caller. */
    function sellCancel(uint256 _orderId) contractInitialised {
        /* If we're closed, throw */
        if (isClosed || smartInvestmentFundToken.isClosed())
            throw;

        cancelOrder(false, _orderId);
    }

    /* Cancels the specified buy order if it is still valid and owned by the caller. */
    function buyCancel(uint256 _orderId) contractInitialised {
        /* If we're closed, throw */
        if (isClosed || smartInvestmentFundToken.isClosed())
            throw;

        /* Determine remaining amount to return */
        uint256 etherToReturn;
        bool found = false;
        for (uint256 i = 0; i < buyOrders.length; i++)
            if (buyOrders[i].id == _orderId && buyOrders[i].account == msg.sender) {
                found = true;
                etherToReturn = buyOrders[i].amountLoaded - buyOrders[i].amountSpent;
                break;
            }
        if (!found)
            throw;
        
        /* Close the order */
        cancelOrder(true, _orderId);

        /* Finally send back the ether to the caller */
        if (etherToReturn > 0 && !msg.sender.send(etherToReturn))
            throw;
    }

    function cancelOrder(bool _isBuy, uint256 _orderId) private {
        /* Mark the order as no longer having any quantity if it belongs to the caller */
        bool found = false;
        uint256 i;
        if (_isBuy) {
            for (i = 0; i < buyOrders.length; i++)
                if (buyOrders[i].id == _orderId && buyOrders[i].account == msg.sender) {
                    buyOrders[i].quantityRemaining = 0;
                    found = true;
                }
        } else {
            for (i = 0; i < sellOrders.length; i++)
                if (sellOrders[i].id == _orderId && sellOrders[i].account == msg.sender) {
                    sellOrders[i].quantityRemaining = 0;
                    found = true;
                }
        }
        if (!found)
            throw;
        
        /* We found it so announce closure */
        OrderClosed(_isBuy ? "Buy" : "Sell", _orderId);

        /* Tidy up the sell / buy orders lists now we've extract the data we care about */
        tidyArrays();
    }

    /* Tidy up the buy and sell order arrays - removing any now-empty items and resizing the arrays accordingly. */
    function tidyArrays() private {
        /* We enumerate through the buy array looking for any with a remaining balance of 0 and shuffle up from there, keep doing this until we get to the end */
        uint256 mainLoopIndex;
        uint256 shuffleIndex;
        for (mainLoopIndex = 0; mainLoopIndex < buyOrders.length; mainLoopIndex++) {
            if (buyOrders[mainLoopIndex].quantityRemaining < 1) {
                /* First lets mark this as closed in the audit */
                OrderClosed("Buy", buyOrders[mainLoopIndex].id);

                /* Attempt to send back any remaining funds that have not been spent */
                uint256 etherToReturn = buyOrders[mainLoopIndex].amountLoaded - buyOrders[mainLoopIndex].amountSpent;
                if (etherToReturn > 0 && !buyOrders[mainLoopIndex].account.send(etherToReturn))
                    throw;

                /* We have an empty order so we need to shuffle all remaining orders down and reduce size of the order book */
                for (shuffleIndex = mainLoopIndex; shuffleIndex < buyOrders.length - 1; shuffleIndex++)
                    buyOrders[shuffleIndex] = buyOrders[shuffleIndex + 1];
                buyOrders.length--;
            }
        }
        for (mainLoopIndex = 0; mainLoopIndex < sellOrders.length; mainLoopIndex++) {
            if (sellOrders[mainLoopIndex].quantityRemaining < 1) {
                /* First lets mark this as closed in the audit */
                OrderClosed("Sell", sellOrders[mainLoopIndex].id);

                /* We have an empty order so we need to shuffle all remaining orders down and reduce size of the order book */
                for (shuffleIndex = mainLoopIndex; shuffleIndex < sellOrders.length - 1; shuffleIndex++)
                    sellOrders[shuffleIndex] = sellOrders[shuffleIndex + 1];
                sellOrders.length--;
            }
        }
    }

    /* Allows an admin to close all open orders and close the entire market place.  Thsi can intentionally happen before ICO is ended - the idea here is to stop any abuse of marketplace or
       to potentially close the marketplace if a bug is somehow found at a future date. */
    function closeMarket(string _details) contractInitialised adminOnly {
        /* Sell orders are pretty simple - just audit their closure */
        uint256 i;
        for (i = 0; i < sellOrders.length; i++)
            OrderClosed("Sell", sellOrders[i].id);
        sellOrders.length = 0;

        /* Buy orders we need to refund any payments */
        for (i = 0; i < buyOrders.length; i++) {
            OrderClosed("Buy", buyOrders[i].id);
            uint256 refundAmount = buyOrders[i].amountLoaded - buyOrders[i].amountSpent;
            if (refundAmount > 0 && !buyOrders[i].account.send(refundAmount))
                /* We cannot stop the whole thing as this is potentially critical code if we're trying to live-fix a defect so we have to enter a withdrawable state */
                failedWithdrawRequests[buyOrders[i].account] += refundAmount;
        }
        buyOrders.length = 0;

        /* Audit this event */
        MarketClosed(_details);

        /* Close the marketplace */
        isClosed = true;
        nextOrderId = 0;
    }

    /* Re-opens a closed marketpalce. */
    function openMarket() contractInitialised adminOnly {
        /* We can only work on closed marketplace */
        if (!isClosed || smartInvestmentFundToken.isClosed())
            throw;
        
        /* Re-open the market */
        MarketOpened();
        isClosed = false;
    }

    /* Allows withdrawal of funds that were allocated after a failed withdrawal during market closure */
    function emergencyWithdrawal() contractInitialised {
        uint256 amountToWithdraw = failedWithdrawRequests[msg.sender];
        if (amountToWithdraw < 1)
            throw;
        failedWithdrawRequests[msg.sender] = 0;
        if (!msg.sender.send(amountToWithdraw))
            throw;
    }

    /* Adds funds that can be used for buyback purposes and are kept in this wallet until buyback is complete */
    function buybackFund() contractInitialised payable adminOnly {
        if (smartInvestmentFundToken.isClosed())
            throw;
        buybackFundAmount += msg.value;
        BuybackFundsAdded(msg.value, buybackFundAmount, "Admin Funding");
    }

    /* Withdraws buyback funds to the calling admin address for use if we ever have issues with buyback process and money that could be re-invested in the fund
       ends up trapped here. */
    function buybackWithdraw() contractInitialised adminOnly {
        if (!msg.sender.send(buybackFundAmount))
            throw;
        BuybackFundsRemoved(buybackFundAmount, 0, "Admin Withdrawal");
        buybackFundAmount = 0;
    }

    /* Sets minimum and maximum amounts for buyback where 0 indicates no limit */
    function buybackSetRates(uint256 _minimum, uint256 _maximum) contractInitialised adminOnly {
        if (smartInvestmentFundToken.isClosed())
            throw;

        /* Store values in public variables */
        buybackMinimumPurchaseAmount = _minimum;
        buybackMaximumPurchaseAmount = _maximum;
    }

    /* Indicates a new buy order could not be fulfilled by the marketplace directly giving a chance for descendent classes to do something with it. */
    function buybackProcess(uint256 orderIndex) private {
        /* Skip if no buyback fund left */
        if (buybackFundAmount < 1)
            return;

        /* Check this sell orders price - is it within our buy/sell range? */
        Order sellOrder = sellOrders[orderIndex];
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
        smartInvestmentFundToken.transferShares(buybackShareholderAccount, sellOrder.account, amountToPurchase);

        /* Now adjust their order */
        sellOrders[orderIndex].quantityRemaining -= amountToPurchase;
        OrderUpdated("Sell", sellOrder.id, sellOrder.price, sellOrders[orderIndex].quantityRemaining);

        /* Finally lets send some ether to the seller minus fees */
        uint256 costToBuy = amountToPurchase * sellOrder.price;
        uint256 transactionCost = costToBuy / 1000 * feePercentageOneDp;
        uint256 amountToSeller = costToBuy - transactionCost;
        if (!sellOrder.account.send(amountToSeller))
            throw;
        buybackFundAmount -= amountToSeller;
        BuybackFundsRemoved(amountToSeller, buybackFundAmount, "Share Buyback");
        buybackFundAmount += transactionCost;
        BuybackFundsAdded(transactionCost, buybackFundAmount, "Marketplace Fee");
    }

    /* Handle being told that an account balance has reduced - we can then cancel orders as appropriate.  This happens when the user sends funds outside of the marketplace. */
    function notifyBalanceReduced(address _from, uint256 _amount) contractInitialised {
        // Ensure we were called from SIFT itself
        if (msg.sender != siftContractAddress)
            return;

        /* We close the most recent trades first (last in, first sacrificed) */
        uint256 toRemove = _amount;
        bool wereAnyClosed = false;
        for (uint256 i = sellOrders.length - 1; i >= 0; i--) {
            /* If this sell order is someone elses, we can ignore it */
            if (sellOrders[i].account != _from)
                continue;

            /* We need to reduce the balance of this sell order by appropriate amount */
            if (toRemove > sellOrders[i].quantityRemaining) {
                toRemove -= sellOrders[i].quantityRemaining;
                sellOrders[i].quantityRemaining = 0;
                wereAnyClosed = true;
            } else {
                sellOrders[i].quantityRemaining -= toRemove;
                OrderUpdated("Sell", sellOrders[i].id, sellOrders[i].price, sellOrders[i].quantityRemaining);
                break;
            }
        }

        /* Consolidate any arrays if we closed any trades */
        if (wereAnyClosed)
            tidyArrays();
    }
}