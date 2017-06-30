pragma solidity ^0.4.11;

contract AdminManagedContract {
    /* Map our users to admins */
    mapping (address => bool) adminUsers;

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
    mapping (address => uint256) balances;

    /* Map between users and their approval addresses and amounts */
    mapping(address => mapping (address => uint256)) allowed;

    /* The name of the contract */
    string public constant name = "Smart Trading Fund";

    /* The symbol for the contract */
    string public constant symbol = "SMRT";

    /* How many DPs are in use in this contract */
    uint8 public constant decimals = 0;

    /* Defines whether or not we are in the ICO phase */
    bool icoPhase = true;

    /* Defines the sale price during ICO */
    uint256 icoUnitPrice = 10 finney;

    uint256 _totalSupply = 0;

    /* Our transfer event to fire whenever we shift SMRT around */
    event Transfer(address indexed from, address indexed to, uint256 value);
    
    /* Our approval event when one user approves another to control */
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);


    /* Initializes contract and adds creator as an admin user */
    function SmartTradingFund() {
    }


    function totalSupply() constant returns (uint256 totalSupply) {
        totalSupply = _totalSupply;
    }

    // What is the balance of a particular account?
    function balanceOf(address _owner) constant returns (uint256 balance) {
        return balances[_owner];
    }
    // Transfer the balance from owner's account to another account
    function transfer(address _to, uint256 _amount) returns (bool success) {
        /* Check if sender has balance and for overflows */
        if (balances[msg.sender] < _amount || balances[_to] + _amount < balances[_to])
            throw;

        /* Add and subtract new balances */
        balances[msg.sender] -= _amount;
        balances[_to] += _amount;

        /* Fire notification event */
        Transfer(msg.sender, _to, _amount);
        success = true;
    }
    
     // Send _value amount of tokens from address _from to address _to
     // The transferFrom method is used for a withdraw workflow, allowing contracts to send
     // tokens on your behalf, for example to "deposit" to a contract address and/or to charge
     // fees in sub-currencies; the command should fail unless the _from account has
     // deliberately authorized the sender of the message via some mechanism; we propose
     // these standardized APIs for approval:
     function transferFrom(
         address _from,
        address _to,
        uint256 _amount
    ) returns (bool success) {
        if (balances[_from] >= _amount
            && allowed[_from][msg.sender] >= _amount
            && _amount > 0
            && balances[_to] + _amount > balances[_to]) {
            balances[_from] -= _amount;
            allowed[_from][msg.sender] -= _amount;
            balances[_to] += _amount;
            Transfer(_from, _to, _amount);
            return true;
        } else {
            return false;
        }
    }
 
    // Allow _spender to withdraw from your account, multiple times, up to the _value amount.
    // If this function is called again it overwrites the current allowance with _value.
    function approve(address _spender, uint256 _amount) returns (bool success) {
        allowed[msg.sender][_spender] = _amount;
        Approval(msg.sender, _spender, _amount);
        return true;
    }

    function allowance(address _owner, address _spender) constant returns (uint256 remaining) {
        return allowed[_owner][_spender];
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