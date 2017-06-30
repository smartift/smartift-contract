pragma solidity ^0.4.11;

contract MarketplaceToken is IcoPhasedContract {
    /* Adds a sell order to the system.  It will follow normal consolidation to attempt to sell as much as possible immediately. */
    function marketplaceSellOrder(uint256 price, uint256 quantity) return(uint256 numberSold, uint256 sellOrderId) onlyAfterIco {
        // Add the sell order

        // Perform market consolidation loop

        // Send an event advertising new sell order if any remaining to sell
    }

    /* Cancels the specified sell order if it is still valid and owned by the caller. */
    function marketplaceSellCancel(uint256 orderId) onlyAfterIco {
        // Send an event indicating sell order has been closed
    }

    /* Adds a buy order to the system.  It will attempt to fulfil it initially (adding numberPurchased) if there are any sell prices that match and any remaining quanity
       will stay on the buyOrderId */
    function marketplaceBuyOrder(uint256 price, uint256 quantity) returns (uint256 numberPurchased, uint256 buyOrderId) {
        numberPurchased = 0;
        buyOrderId = 0;

        // Add the buy order

        // Perform market consolidation loop

        // If we have any remaining quantity to buy
    }

    /* Cancels the specified buy order if it is still valid and owned by the caller. */
    function marketplaceBuyCancel(uint256 orderId) onlyAfterIco {
        // Send an event indicating buy order has been closed
    }

    /* Consolidates buy orders against sell orders.  Fires events as items are bought/sold including a current market price based on this.  Buy orders are processed against sell orders with lowest price being purchased
       first and the oldest at that price.  Once the oldest at the price are bought then the more new, etc.  This continues until that price is exuahsted for the buy order and it continues for the next lowest price - again
       aged oldest to newest.  If there are no buy orders between buyback low/high price and sell orders still exist and we hold ether then the coin itself will buy it at the cheapest price it can and transfer the holding
       to the shareholder address. */
    function marketConsolidation() {

    }
}