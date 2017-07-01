pragma solidity ^0.4.11;
import "IcoPhasedContract.sol";

contract MarketplaceToken is IcoPhasedContract {
    struct Order {
        uint256 id;
        uint256 price;
        uint256 quantityRemaining;
        uint256 quantityStart;
        address account;
    }

    /* Defines all the sell orders in the system */
    Order[] public sellOrders;

    /* Defines all the buy orders in the system */
    Order[] public buyOrders;

    /* The percentage fee to take for any SELL transactions in ether.  This is based to one DP so 1 = 0.1%, 10 = 1% and 1000 = 100%. */
    uint256 feePercentageOneDp;

    /* Defines the ID of the next order (buy or sell) that we will create. */
    uint256 nextOrderId;

    /* Announces an order is opened */
    event MarketplaceOrderOpened(string orderType, uint256 id, uint256 price, uint256 quantity);

    /* Announces an order is updated */
    event MarketplaceOrderUpdated(string orderType, uint256 id, uint256 price, uint256 quantity);

    /* Announce an order has been closed */
    event MarketplaceOrderClosed(string orderType, uint256 id);

    function MarketplaceToken(uint256 _feePercentageOneDp) {
        feePercentageOneDp = _feePercentageOneDp;
        nextOrderId = 0;
    }

    /* Adds a sell order to the system.  It will follow normal consolidation method. */
    function marketplaceSellOrder(uint256 price, uint256 quantity) onlyAfterIco returns(uint256 numberSold, uint256 sellOrderId) {
        (numberSold, sellOrderId) = marketplaceOrder(false, price, quantity);
    }

    /* Adds a buy order to the system.  It will follow normal consolidation method. */
    function marketplaceBuyOrder(uint256 price, uint256 quantity) onlyAfterIco returns(uint256 numberPurchased, uint256 buyOrderId) {
        (numberPurchased, buyOrderId) = marketplaceOrder(true, price, quantity);
    }

    /* Adds a buy or sell order to the system.  It will follow normal consolidation method. */
    function marketplaceOrder(bool isBuy, uint256 price, uint256 quantity) private returns (uint256 number, uint256 id) {
        // Add the order
        if (isBuy) {
            buyOrders.length++;
            buyOrders[buyOrders.length - 1] = Order(nextOrderId, price, quantity, quantity, msg.sender);
        } else {
            sellOrders.length++;
            sellOrders[sellOrders.length - 1] = Order(nextOrderId, price, quantity, quantity, msg.sender);
        }

        // Audit the creation
        MarketplaceOrderOpened(isBuy ? "Buy" : "Sell", nextOrderId, price, quantity);

        // Perform market consolidation loop
        marketplaceConsolidation();
        Order newOrder = isBuy ? buyOrders[buyOrders.length - 1] : sellOrders[sellOrders.length - 1];

        // Determine our return values
        number = quantity - newOrder.quantityRemaining;
        id  = nextOrderId;
        nextOrderId++;

        // Tidy up the sell / buy orders lists now we've extract the data we care about
        marketplaceTidyArrays();
    }

    /* Cancels the specified sell order if it is still valid and owned by the caller. */
    function marketplaceSellCancel(uint256 orderId) onlyAfterIco {
        marketplaceCancel(false, orderId);
    }

    /* Cancels the specified buy order if it is still valid and owned by the caller. */
    function marketplaceBuyCancel(uint256 orderId) onlyAfterIco {
        marketplaceCancel(true, orderId);
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

    /* Consolidates buy orders against sell orders.  Fires events as items are bought/sold including a current market price based on this.  Buy orders are processed against sell orders with lowest price being purchased
       first and the oldest at that price.  Once the oldest at the price are bought then the more new, etc.  This continues until that price is exuahsted for the buy order and it continues for the next lowest price - again
       aged oldest to newest.  If there are no buy orders between buyback low/high price and sell orders still exist and we hold ether then the coin itself will buy it at the cheapest price it can and transfer the holding
       to the shareholder address. */
    function marketplaceConsolidation() private {
        // We probably want a transaction fee here and an address to send it to or an admin method to withdraw or keep it in fund - buyback?

        // We want to announce sell/buy order quantities here (including those we've just created)

        // Call buybackProcessOrderBook
    }

    /* Tidy up the buy and sell order arrays - removing any now-empty items and resizing the arrays accordingly. */
    function marketplaceTidyArrays() private {
        // TODO: Remove empty orders from buy and sell books
    }

    function buybackProcessOrderBook() private;
}