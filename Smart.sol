pragma solidity ^0.4.11;
import "Erc20Token.sol";
import "IcoPhasedContract.sol";
import "MarketplaceToken.sol";

contract SmartInvestmentFund is Erc20Token("Smart Investment Fund", "SIF", 0), IcoPhasedContract, MarketplaceToken {
    /* Sets the shareholder account for auto buyback */
    address shareholderAccount;

    /* Defines the sale price during ICO */
    uint256 constant icoUnitPrice = 10 finney;

    /* Fired whenever the shareholder for buyback is changed */
    event AuditShareholder(address shareholder);

    /* Initializes contract and adds creator as an admin user */
    function SmartTradingFund() {
        // Set the first admin to be the person creating the contract
        adminUsers[msg.sender] = true;
        AuditAdminAdded(msg.sender);

        // Set the shareholder to initially be the contract creator
        shareholderAccount = msg.sender;
        AuditShareholder(msg.sender);
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
    function shareholderSet(address shareholder) adminOnly {
        shareholderAccount = shareholder;
        AuditShareholder(shareholder);
    }

    /* Makes a dividend payment - we send it to all coin holders but we exclude any coins held in the shareholder account as the equivalent dividend is excluded prior to paying in to reduce overall
       transaction fees */
    function dividendPay() payable adminOnly onlyAfterIco {
        // Determine how much coin supply we have minus that held by shareholder

        // Work out from this a dividend per share

        // Enum all accounts and 

        // Rather than sending any rounding errors back we hold for our buyback potentials - add audit for this
    }

    /* Adds funds that can be used for buyback purposes and are kept in this wallet until buyback is complete */
    function buybackAddFunds() payable adminOnly onlyAfterIco {
        // Just audit this
    }

    /* Sets minimum and maximum amounts for buyback where 0 indicates no limit */
    function buybackSetLimits(uint256 minimum, uint256 maximum) adminOnly onlyAfterIco {
        // Store values in public variables    }

    /* Defines the current value of the funds assets in USD and ETHER */
    function fundValueSet(uint256 usdTotalFund, uint256 etherTotalFund) adminOnly onlyAfterIco {
        // Store values

        // Audit this
    }

}