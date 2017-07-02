pragma solidity ^0.4.11;
import "IcoPhasedContract.sol";
import "Erc20Token.sol";

contract MarketplaceToken is IcoPhasedContract, Erc20Token("Smart Investment Fund", "SIF", 0) {
    struct Order {
        uint256 id;
        uint256 price;
        uint256 quantityRemaining;
        uint256 quantityStart;
        address account;
        uint256 timestamp;
        uint256 amountLoaded;
        uint256 amountSpent;
    }

    /* Defines a map allowing people to withdraw funds if a market was closed and repayment failed */
    mapping (address => uint256) failedWithdrawRequests;

    /* Defines all the sell orders in the system */
    Order[] public sellOrders;

    /* Defines all the buy orders in the system */
    Order[] public buyOrders;

    /* The percentage fee to take for any SELL transactions in ether.  This is based to one DP so 1 = 0.1%, 10 = 1% and 1000 = 100%. */
    uint256 feePercentageOneDp;

    /* Defines the ID of the next order (buy or sell) that we will create. */
    uint256 nextOrderId;

    /* Defines if the marketplace is currently closed */
    bool isClosed;

    /* Announces an order is opened */
    event MarketplaceOrderOpened(string orderType, uint256 id, uint256 price, uint256 quantity);

    /* Announces an order is updated */
    event MarketplaceOrderUpdated(string orderType, uint256 id, uint256 price, uint256 quantity);

    /* Announce an order has been closed */
    event MarketplaceOrderClosed(string orderType, uint256 id);

    /* Announce that an admin closed all orders for some reason */
    event MarketplaceAdminClosed(string details);

    /* Announces that the marketplace has been opened. */
    event MarketplaceAdminOpened();

    function MarketplaceToken(uint256 _feePercentageOneDp) {
        feePercentageOneDp = _feePercentageOneDp;
        nextOrderId = 0;
        isClosed = false;
    }

    /* Adds a sell order to the system.  It will follow normal consolidation method. */
    function marketplaceSellOrder(uint256 price, uint256 quantity) onlyAfterIco returns(uint256 numberSold, uint256 id) {
        // If we're closed, throw
        if (isClosed)
            throw;

        // Add the order
        sellOrders.length++;
        sellOrders[sellOrders.length - 1] = Order(nextOrderId, price, quantity, quantity, msg.sender, block.timestamp, 0, 0);

        // Audit the creation
        MarketplaceOrderOpened("Sell", nextOrderId, price, quantity);

        // Do we have any remaining to purchase if this was a sell?  If so let's use our buybackProcessOrderBook()
        Order newOrder = sellOrders[sellOrders.length - 1];
        if (newOrder.quantityRemaining > 0)
            buybackProcessOrderBook();

        // Determine our return values
        numberSold = quantity - newOrder.quantityRemaining;
        id  = nextOrderId;
        nextOrderId++;

        // Tidy up the sell / buy orders lists now we've extract the data we care about
        marketplaceTidyArrays();
    }

    /* Adds a buy order to the system.  It will follow normal consolidation method. */
    function marketplaceBuyOrder(uint256 price, uint256 quantity) onlyAfterIco payable returns(uint256 numberPurchased, uint256 id) {
        // If we're closed, throw
        if (isClosed)
            throw;

        // Ensure correct value was sent with the buy - we store the ether
        if (msg.value != quantity * price)
            throw;

        // Create the order
        buyOrders.length++;
        buyOrders[buyOrders.length - 1] = Order(nextOrderId, price, quantity, quantity, msg.sender, block.timestamp, msg.value, 0);

        // Audit the creation
        MarketplaceOrderOpened("Buy", nextOrderId, price, quantity);

        // Do an initial sift to determine the lowest price that is within our price range in the stack
        uint256 cheapestPrice = 0;
        bool validPricesExist = false;
        uint256 sellIndex;
        Order buyOrder = buyOrders[buyOrders.length - 1];
        for (sellIndex = 0; sellIndex < sellOrders.length; sellIndex++)
            if (sellOrders[sellIndex].quantityRemaining > 0 && sellOrders[sellIndex].price <= buyOrder.price && (!validPricesExist || sellOrders[sellIndex].price < cheapestPrice)) {
                cheapestPrice = sellOrders[sellIndex].price;
                validPricesExist = true;
            }
        
        // As long as other cheap prices still exist, keep looping and closing for this price
        while (validPricesExist) {
            // In this loop we do two things - firstly if the order is at loopPrice, we buy up to theirs and our maximum quantity.  Secondly we look for the next-cheapest price.
            uint256 loopPrice = cheapestPrice;
            validPricesExist = false;
            for (sellIndex = 0; sellIndex < sellOrders.length; sellIndex++) {
                // First - if the price of this particular order is at the price we're looking for - we can trade and then re-loop
                Order sellOrder = sellOrders[sellIndex];
                if (sellOrder.price == loopPrice && sellOrder.quantityRemaining > 0) {
                    // Decide how many we want to buy
                    uint256 numberToBuy = buyOrder.quantityRemaining > sellOrder.quantityRemaining ? sellOrder.quantityRemaining : buyOrder.quantityRemaining;
                    uint256 costToBuy = numberToBuy * sellOrder.price;
                    if (costToBuy + buyOrder.amountSpent > buyOrder.amountLoaded)
                        // If this somehow happens it is a bug but we cannot allow spending money that isn't there
                        throw;

                    // Update the orders respectively including audit
                    sellOrders[sellIndex].quantityRemaining -= numberToBuy;
                    buyOrder.quantityRemaining -= numberToBuy; // For local count
                    buyOrder.amountSpent += costToBuy;
                    buyOrders[buyOrders.length - 1].quantityRemaining -= numberToBuy; // For main list
                    buyOrders[buyOrders.length - 1].amountSpent += costToBuy;
                    MarketplaceOrderUpdated("Buy", buyOrder.id, buyOrder.price, buyOrder.quantityRemaining);
                    MarketplaceOrderUpdated("Sell", sellOrder.id, sellOrder.price, sellOrders[sellIndex].quantityRemaining);

                    // Transfer tokens from sell order account to buy order account - include a Transfer() here and update the token recipient lists
                    balances[sellOrder.account] -= numberToBuy;
                    bool isBuyerNew = balances[buyOrder.account] > 0;
                    balances[buyOrder.account] += numberToBuy;
                    if (isBuyerNew)
                        tokenOwnerAdd(buyOrder.account);
                    if (balances[sellOrder.account] < 1)
                        tokenOwnerRemove(sellOrder.account);
                    Transfer(sellOrder.account, buyOrder.account, numberToBuy);

                    // Send ether to person with sell order
                    uint256 transactionCost = costToBuy / 1000 * feePercentageOneDp;
                    uint256 amountToSeller = costToBuy - transactionCost;
                    if (!sellOrder.account.send(amountToSeller))
                        throw;
                    marketplaceTransactionCostAvailable(transactionCost);

                    // If nothing remaining to buy, we can stop here
                    if (buyOrder.quantityRemaining < 1)
                        break;

                    // Loop for next one
                    continue;
                }

                // Second - if we're still here the question is will this become the new cheapest price?
                if (sellOrder.price > loopPrice && sellOrder.quantityRemaining > 0 && sellOrder.price <= buyOrder.price && (!validPricesExist || sellOrder.price < cheapestPrice)) {
                    cheapestPrice = sellOrders[sellIndex].price;
                    validPricesExist = true;
                }
            }

            // If the buy order is closed, we can stop looking
            if (buyOrder.quantityRemaining < 1)
                break;
        }

        // Determine our return values
        Order newOrder = buyOrders[buyOrders.length - 1];
        numberPurchased = quantity - newOrder.quantityRemaining;
        id  = nextOrderId;
        nextOrderId++;

        // Tidy up the sell / buy orders lists now we've extract the data we care about
        marketplaceTidyArrays();
    }

    /* Cancels the specified sell order if it is still valid and owned by the caller. */
    function marketplaceSellCancel(uint256 orderId) onlyAfterIco {
        // If we're closed, throw
        if (isClosed)
            throw;

        marketplaceCancel(false, orderId);
    }

    /* Cancels the specified buy order if it is still valid and owned by the caller. */
    function marketplaceBuyCancel(uint256 orderId) onlyAfterIco {
        // If we're closed, throw
        if (isClosed)
            throw;

        // Determine remaining amount to return
        uint256 etherToReturn;
        bool found = false;
        for (uint256 i = 0; i < buyOrders.length; i++)
            if (buyOrders[i].id == orderId && buyOrders[i].account == msg.sender) {
                found = true;
                etherToReturn = buyOrders[i].amountLoaded - buyOrders[i].amountSpent;
                break;
            }
        if (!found)
            throw;
        
        // Close the order
        marketplaceCancel(true, orderId);

        // Finally send back the ether to the caller
        if (etherToReturn > 0 && !msg.sender.send(etherToReturn))
            throw;
    }

    function marketplaceCancel(bool isBuy, uint256 orderId) private {
        // Mark the order as no longer having any quantity if it belongs to the caller
        bool found = false;
        uint256 i;
        if (isBuy) {
            for (i = 0; i < buyOrders.length; i++)
                if (buyOrders[i].id == orderId && buyOrders[i].account == msg.sender) {
                    buyOrders[i].quantityRemaining = 0;
                    found = true;
                }
        } else {
            for (i = 0; i < sellOrders.length; i++)
                if (sellOrders[i].id == orderId && sellOrders[i].account == msg.sender) {
                    sellOrders[i].quantityRemaining = 0;
                    found = true;
                }
        }
        if (!found)
            throw;
        
        // We found it so announce closure
        MarketplaceOrderClosed(isBuy ? "Buy" : "Sell", orderId);

        // Tidy up the sell / buy orders lists now we've extract the data we care about
        marketplaceTidyArrays();
    }

    /* Tidy up the buy and sell order arrays - removing any now-empty items and resizing the arrays accordingly. */
    function marketplaceTidyArrays() private {
        // We enumerate through the buy array looking for any with a remaining balance of 0 and shuffle up from there, keep doing this until we get to the end
        uint256 mainLoopIndex;
        uint256 shuffleIndex;
        for (mainLoopIndex = 0; mainLoopIndex < buyOrders.length; mainLoopIndex++) {
            if (buyOrders[mainLoopIndex].quantityRemaining < 1) {
                // First lets mark this as closed in the audit
                MarketplaceOrderClosed("Buy", buyOrders[mainLoopIndex].id);

                // Attempt to send back any remaining funds that have not been spent
                uint256 etherToReturn = buyOrders[mainLoopIndex].amountLoaded - buyOrders[mainLoopIndex].amountSpent;
                if (etherToReturn > 0 && !buyOrders[mainLoopIndex].account.send(etherToReturn))
                    throw;

                // We have an empty order so we need to shuffle all remaining orders down and reduce size of the order book
                for (shuffleIndex = mainLoopIndex; shuffleIndex < buyOrders.length - 1; shuffleIndex++)
                    buyOrders[shuffleIndex] = buyOrders[shuffleIndex + 1];
                buyOrders.length--;
            }
        }
        for (mainLoopIndex = 0; mainLoopIndex < sellOrders.length; mainLoopIndex++) {
            if (sellOrders[mainLoopIndex].quantityRemaining < 1) {
                // First lets mark this as closed in the audit
                MarketplaceOrderClosed("Sell", sellOrders[mainLoopIndex].id);

                // We have an empty order so we need to shuffle all remaining orders down and reduce size of the order book
                for (shuffleIndex = mainLoopIndex; shuffleIndex < sellOrders.length - 1; shuffleIndex++)
                    sellOrders[shuffleIndex] = sellOrders[shuffleIndex + 1];
                sellOrders.length--;
            }
        }
    }

    /* Allows an admin to close all open orders and close the entire market place.  Thsi can intentionally happen before ICO is ended - the idea here is to stop any abuse of marketplace or
       to potentially close the marketplace if a bug is somehow found at a future date. */
    function marketplaceCloseAll(string details) adminOnly {
        // Sell orders are pretty simple - just audit their closure
        uint256 i;
        for (i = 0; i < sellOrders.length; i++)
            MarketplaceOrderClosed("Sell", sellOrders[i].id);
        sellOrders.length = 0;

        // Buy orders we need to refund any payments
        for (i = 0; i < buyOrders.length; i++) {
            MarketplaceOrderClosed("Buy", buyOrders[i].id);
            uint256 refundAmount = buyOrders[i].amountLoaded - buyOrders[i].amountSpent;
            if (refundAmount > 0 && !buyOrders[i].account.send(refundAmount))
                // We cannot stop the whole thing as this is potentially critical code if we're trying to live-fix a defect so we have to enter a withdrawable state
                failedWithdrawRequests[buyOrders[i].account] += refundAmount;
        }
        buyOrders.length = 0;

        // Audit this event
        MarketplaceAdminClosed(details);

        // Close the marketplace
        isClosed = true;
        nextOrderId = 0;
    }

    /* Re-opens a closed marketpalce. */
    function marketplaceOpen() adminOnly {
        // We can only work on closed marketplace
        if (!isClosed)
            throw;
        
        // Re-open the market
        MarketplaceAdminOpened();
        isClosed = false;
    }

    /* Allows withdrawal of funds that were allocated after a failed withdrawal during market closure */
    function marketplaceEmergencyWithdrawal() {
        uint256 amountToWithdraw = failedWithdrawRequests[msg.sender];
        if (amountToWithdraw < 1)
            throw;
        failedWithdrawRequests[msg.sender] = 0;
        if (!msg.sender.send(amountToWithdraw))
            throw;
    }

    function buybackProcessOrderBook() private;

    /* Handle the transaction fee from a sell order being available to the contract. */
    function marketplaceTransactionCostAvailable(uint256 amount) private;
}