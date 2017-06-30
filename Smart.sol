pragma solidity ^0.4.11;

contract AdminManagedContract {
    /* Map our users to admins */
    mapping (address => bool) public adminUsers;

    function AdminManagedContract() {
        adminUsers[msg.sender] = true;
    }

    modifier adminOnly {
        if (!adminUsers[msg.sender]) throw;
        _;
    }

    function adminAdd(address _adminAddress) adminOnly {
        adminUsers[_adminAddress] = true;
    }
    function adminRemove(address _adminAddress) adminOnly {
        // Don't allow removal of self
        if (_adminAddress == msg.sender)
            throw;

        // Remove this admin user
        adminUsers[_adminAddress] = false;
    }
}

contract SmartTradingFund is AdminManagedContract {
    /* Map all our our balances for issued tokens */
    mapping (address => uint256) public smartBalances;

    /* The name of the contract */
    string public name = "Smart Trading Fund";

    /* The symbol for the contract */
    string public symbol = "SMRT";

    /* How many DPs are in use in this contract */
    uint8 public decimals = 0;

    /* Defines whether or not we are in the ICO phase */
    bool public icoPhase = true;

    /* Defines the sale price during ICO */
    uint256 icoUnitPrice = 10 finney;

    /* Our transfer event to fire whenever we shift SMRT around */
    event Transfer(address indexed from, address indexed to, uint256 value);
    event DebugStr(string message);
    event DebugInt(uint256 message);
    event DebugAcct(address message);

    /* Initializes contract and adds creator as an admin user */
    function SmartTradingFund() {
    }

    /* Send SMRT to specified recipient */
    function transfer(address _to, uint256 _value) {
        /* Check if sender has balance and for overflows */
        if (smartBalances[msg.sender] < _value || smartBalances[_to] + _value < smartBalances[_to])
            throw;

        /* Add and subtract new balances */
        smartBalances[msg.sender] -= _value;
        smartBalances[_to] += _value;

        /* Fire notification event */
        Transfer(msg.sender, _to, _value);
    }

    /* Ensures a function can only be called during the ICO */
    modifier preIco {
        if (!icoPhase) throw;
        _;
    }
    /* Ensures a function can only be called after the ICO */
    modifier postIco {
        if (icoPhase) throw;
        _;
    }

    /* Close the ICO phase and transition to execution phase */
    function closeIco() adminOnly preIco {
        icoPhase = false;
    }

    /* Handle the defautl method depending on whether we're in ICO or not the actions are different */
    function () payable {
        if (icoPhase)
            receiveEtherIco();
        else
            receiveEtherLive();
    }

    /* Handle receiving ether in ICO phase - we work out how much the user has bought, allocate a suitable balance and send their change */
    function receiveEtherIco() private preIco {
        // Determine how much they've actually purhcased and any ether change
        uint256 tokensPurchased = msg.value / icoUnitPrice;
        uint256 purchaseTotalPrice = tokensPurchased * icoUnitPrice;
        uint256 change = msg.value - purchaseTotalPrice;
        DebugStr("User purchased");
        DebugInt(tokensPurchased);
        DebugStr("Change of ");
        DebugInt(change);

        // Increase their new balance if trhey actually purchased any
        if (tokensPurchased > 0)
            smartBalances[msg.sender] += tokensPurchased;

        // Send change back to recipient
        if (change > 0) {
            DebugStr("Sending change back to");
            DebugAcct(msg.sender);
            if (!msg.sender.send(change))
                throw;
        }
        
        // Fire transfer event
        Transfer(0, msg.sender, tokensPurchased);
    }

    function receiveEtherLive() private postIco {
        // For now we don't know what to do
        throw;
    }

    /* ToDo 
    Add live ether dividend support
    cashOut - not just ICO
    Icon?
    Base contracts abstract?
    "Gas is paid by the owner of the wallet contract (0.00 ETHER)" (addNetworkFunds ??)
    cancel/sell/buy share sales / list sahres
    Split inheritance into different files
    ERC20 Support
    */
}