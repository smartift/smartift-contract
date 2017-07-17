pragma solidity ^0.4.11;
import "Erc20Token.sol";
import "IcoPhaseManagement.sol";
import "SafeMath.sol";

/* The SIFT itself is a simple extension of the ERC20 that allows for granting other SIFT contracts special rights to act on behalf of all transfers. */
contract SmartInvestmentFundToken is Erc20Token("Smart Investment Fund Token", "SIFT", 0) {
    using SafeMath for uint256;

    /* Defines the address of the ICO contract which is the only contract permitted to mint tokens. */
    address public icoContractAddress;

    /* Defines whether or not the fund is closed. */
    bool public isClosed;

    /* Defines the contract handling the ICO phase. */
    IcoPhaseManagement icoPhaseManagement;

    /* Fired when the fund is eventually closed. */
    event FundClosed();
    
    /* Create a new instance of this fund with links to other contracts that are required. */
    function SmartInvestmentFundToken(address _icoContractAddress) {
        /* Setup access to our other contracts and validate their versions */
        icoPhaseManagement = IcoPhaseManagement(_icoContractAddress);
        if (icoPhaseManagement.contractVersion() != 300201707071208)
            throw;
        
        /* Store our special addresses */
        icoContractAddress = _icoContractAddress;
    }

    /* Gets the contract version for validation */
    function contractVersion() constant returns(uint256) {
        /* SIFT contract identifies as 500YYYYMMDDHHMM */
        return 500201707171440;
    }

    /* Mint new tokens - this can only be done by special callers (i.e. the ICO management) during the ICO phase. */
    function mintTokens(address _address, uint256 _amount) {
        /* Ensure we are the ICO contract calling */
        if (msg.sender != icoContractAddress || !icoPhaseManagement.icoPhase())
            throw;

        /* Mint the tokens for the new address*/
        bool isNew = balances[_address] == 0;
        totalSupplyAmount = totalSupplyAmount.add(_amount);
        balances[_address] = balances[_address].add(_amount);
        if (isNew)
            tokenOwnerAdd(_address);
        Transfer(0, _address, _amount);
    }
}