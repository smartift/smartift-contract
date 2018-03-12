pragma solidity ^0.4.11;
import "SafeMath.sol";

/* The SIFT itself is a simple extension of the ERC20 that allows for granting other SIFT contracts special rights to act on behalf of all transfers. */
contract SmartInvestmentFundToken {
    using SafeMath for uint256;

    /* Map all our our balances for issued tokens */
    mapping (address => uint256) balances;

    /* Map between users and their approval addresses and amounts */
    mapping(address => mapping (address => uint256)) allowed;

    /* List of all token holders */
    address[] allTokenHolders;

    /* The name of the contract */
    string public name;

    /* The symbol for the contract */
    string public symbol;

    /* How many DPs are in use in this contract */
    uint8 public decimals;

    /* Defines the current supply of the token in its own units */
    uint256 public totalSupply = 722935;

    /* Our transfer event to fire whenever we shift SMRT around */
    event Transfer(address indexed from, address indexed to, uint256 value);
    
    /* Our approval event when one user approves another to control */
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);

    /* Create a new instance of this fund with links to other contracts that are required. */
    function SmartInvestmentFundToken(address _issueTo) public {
        // Setup defaults
        name = "Gas Hog SIFT";
        symbol = "XSFT";
        decimals = 0;

		// Set up for 700 token holders plus main holder.  The 700 just have 1 SIFT
        allTokenHolders.length = 701;
		/*
		for (uint256 i = 1; i < 701; i++) {
			allTokenHolders[i] = address(i);
			balances[address(i)] = 1;
		}
		*/

		// Issue all the SIFT (apart from 700) to _issueTo as fixed supply
		allTokenHolders[0] = _issueTo;
		balances[_issueTo] = 722735;
    }
	
    modifier onlyPayloadSize(uint numwords) {
        assert(msg.data.length == numwords * 32 + 4);
        _;
    } 

    /* Transfer funds between two addresses that are not the current msg.sender - this requires approval to have been set separately and follows standard ERC20 guidelines */
    function transferFrom(address _from, address _to, uint256 _amount) onlyPayloadSize(3) public returns (bool) {
        if (balances[_from] >= _amount && allowed[_from][msg.sender] >= _amount && _amount > 0 && balances[_to].add(_amount) > balances[_to]) {
            bool isNew = balances[_to] == 0;
            balances[_from] = balances[_from].sub(_amount);
            allowed[_from][msg.sender] = allowed[_from][msg.sender].sub(_amount);
            balances[_to] = balances[_to].add(_amount);
            if (isNew)
                tokenOwnerAdd(_to);
            if (balances[_from] == 0)
                tokenOwnerRemove(_from);
            Transfer(_from, _to, _amount);
            return true;
        }
        return false;
    }
 
    /* Adds an approval for the specified account to spend money of the message sender up to the defined limit */
    function approve(address _spender, uint256 _amount) onlyPayloadSize(2) public returns (bool success) {
        allowed[msg.sender][_spender] = _amount;
        Approval(msg.sender, _spender, _amount);
        return true;
    }

    /* Gets the current allowance that has been approved for the specified spender of the owner address */
    function allowance(address _owner, address _spender) public constant returns (uint256 remaining) {
        return allowed[_owner][_spender];
    }

    /* Gets the balance of a specified account */
    function balanceOf(address _owner) public constant returns (uint256 balance) {
        return balances[_owner];
    }

    /* Transfer the balance from owner's account to another account */
    function transfer(address _to, uint256 _amount) public onlyPayloadSize(2) returns (bool) {
        /* Check if sender has balance and for overflows */
        if (balances[msg.sender] < _amount || balances[_to].add(_amount) < balances[_to])
            return false;

        /* Do a check to see if they are new, if so we'll want to add it to our array */
        bool isRecipientNew = balances[_to] < 1;

        /* Add and subtract new balances */
        balances[msg.sender] = balances[msg.sender].sub(_amount);
        balances[_to] = balances[_to].add(_amount);

        /* Consolidate arrays if they are new or if sender now has empty balance */
        if (isRecipientNew)
            tokenOwnerAdd(_to);
        if (balances[msg.sender] < 1)
            tokenOwnerRemove(msg.sender);

        /* Fire notification event */
        Transfer(msg.sender, _to, _amount);
        return true;
    }

    /* If the specified address is not in our owner list, add them - this can be called by descendents to ensure the database is kept up to date. */
    function tokenOwnerAdd(address _addr) internal {
        /* First check if they already exist */
        uint256 tokenHolderCount = allTokenHolders.length;
        for (uint256 i = 0; i < tokenHolderCount; i++)
            if (allTokenHolders[i] == _addr)
                /* Already found so we can abort now */
                return;
        
        /* They don't seem to exist, so let's add them */
        allTokenHolders.length++;
        allTokenHolders[allTokenHolders.length - 1] = _addr;
    }

    /* If the specified address is in our owner list, remove them - this can be called by descendents to ensure the database is kept up to date. */
    function tokenOwnerRemove(address _addr) internal {
        /* Find out where in our array they are */
        uint256 tokenHolderCount = allTokenHolders.length;
        uint256 foundIndex = 0;
        bool found = false;
        uint256 i;
        for (i = 0; i < tokenHolderCount; i++)
            if (allTokenHolders[i] == _addr) {
                foundIndex = i;
                found = true;
                break;
            }
        
        /* If we didn't find them just return */
        if (!found)
            return;
        
        /* We now need to shuffle down the array */
        for (i = foundIndex; i < tokenHolderCount - 1; i++)
            allTokenHolders[i] = allTokenHolders[i + 1];
        allTokenHolders.length--;
    }
}