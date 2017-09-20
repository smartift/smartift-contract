pragma solidity ^0.4.11;
import "AuthenticationManager.sol";
import "SafeMath.sol";

contract VotingBase {
    using SafeMath for uint256;

    /* Map all our our balances for issued tokens */
    mapping (address => uint256) public voteCount;

    /* List of all token holders */
    address[] public voterAddresses;

    /* Defines the admin contract we interface with for credentails. */
    AuthenticationManager internal authenticationManager;

    /* Unix epoch voting starts at */
    uint256 public voteStartTime;

    /* Unix epoch voting ends at */
    uint256 public voteEndTime;

    /* This modifier allows a method to only be called by current admins */
    modifier adminOnly {
        if (!authenticationManager.isCurrentAdmin(msg.sender)) throw;
        _;
    }

    function setVoterCount(uint256 _count) adminOnly {
        // Forbid after voting has started
        if (now >= voteStartTime)
            throw;

        /* Clear existing voter count */
        for (uint256 i = 0; i < voterAddresses.length; i++) {
            address voter = voterAddresses[i];
            voteCount[voter] = 0;
        }

        /* Set the count accordingly */
        voterAddresses.length = _count;
    }

    function setVoter(uint256 _position, address _voter, uint256 _voteCount) adminOnly {
        // Forbid after voting has started
        if (now >= voteStartTime)
            throw;

        if (_position >= voterAddresses.length)
            throw;
            
        voterAddresses[_position] = _voter;
        voteCount[_voter] = _voteCount;
    }
}