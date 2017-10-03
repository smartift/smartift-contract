pragma solidity ^0.4.11;
import "VotingBase.sol";
import "SafeMath.sol";

contract VoteSvp002 is VotingBase {
    using SafeMath for uint256;

    /* Votes for SVP002-01.  0 = not votes, 1 = Yes, 2 = No */
     mapping (address => uint256) vote01;
     uint256 public vote01YesCount;
     uint256 public vote01NoCount;

    /* Votes for SVP002-02.  0 = not votes, 1 = Yes, 2 = No */
     mapping (address => uint256) vote02;
     uint256 public vote02YesCount;
     uint256 public vote02NoCount;

    /* Votes for SVP003-02.  0 = not votes, 1 = Yes, 2 = No */
     mapping (address => uint256) vote03;
     uint256 public vote03YesCount;
     uint256 public vote03NoCount;

    /* Create our contract with references to other contracts as required. */
    function VoteSvp002(address _authenticationManagerAddress, uint256 _voteStartTime, uint256 _voteEndTime) {
        /* Setup access to our other contracts and validate their versions */
        authenticationManager = AuthenticationManager(_authenticationManagerAddress);
        if (authenticationManager.contractVersion() != 100201707171503)
            throw;

        /* Store start/end times */
        if (_voteStartTime >= _voteEndTime)
            throw;
        voteStartTime = _voteStartTime;
        voteEndTime = _voteEndTime;
    }

     function voteSvp01(bool vote) {
        // Forbid outside of voting period
        if (now < voteStartTime || now > voteEndTime)
            throw;

         /* Ensure they have voting rights first */
         uint256 voteWeight = voteCount[msg.sender];
         if (voteWeight == 0)
            throw;
        
        /* Set their vote */
        uint256 existingVote = vote01[msg.sender];
        uint256 newVote = vote ? 1 : 2;
        if (newVote == existingVote)
            /* No change so just return */
            return;
        vote01[msg.sender] = newVote;

        /* If they had voted previous first decrement previous vote count */
        if (existingVote == 1)
            vote01YesCount -= voteWeight;
        else if (existingVote == 2)
            vote01NoCount -= voteWeight;
        if (vote)
            vote01YesCount += voteWeight;
        else
            vote01NoCount += voteWeight;
     }

     function voteSvp02(bool vote) {
        // Forbid outside of voting period
        if (now < voteStartTime || now > voteEndTime)
            throw;

         /* Ensure they have voting rights first */
         uint256 voteWeight = voteCount[msg.sender];
         if (voteWeight == 0)
            throw;
        
        /* Set their vote */
        uint256 existingVote = vote02[msg.sender];
        uint256 newVote = vote ? 1 : 2;
        if (newVote == existingVote)
            /* No change so just return */
            return;
        vote02[msg.sender] = newVote;

        /* If they had voted previous first decrement previous vote count */
        if (existingVote == 1)
            vote02YesCount -= voteWeight;
        else if (existingVote == 2)
            vote02NoCount -= voteWeight;
        if (vote)
            vote02YesCount += voteWeight;
        else
            vote02NoCount += voteWeight;
     }

     function voteSvp03(bool vote) {
        // Forbid outside of voting period
        if (now < voteStartTime || now > voteEndTime)
            throw;

         /* Ensure they have voting rights first */
         uint256 voteWeight = voteCount[msg.sender];
         if (voteWeight == 0)
            throw;
        
        /* Set their vote */
        uint256 existingVote = vote03[msg.sender];
        uint256 newVote = vote ? 1 : 2;
        if (newVote == existingVote)
            /* No change so just return */
            return;
        vote03[msg.sender] = newVote;

        /* If they had voted previous first decrement previous vote count */
        if (existingVote == 1)
            vote03YesCount -= voteWeight;
        else if (existingVote == 2)
            vote03NoCount -= voteWeight;
        if (vote)
            vote03YesCount += voteWeight;
        else
            vote03NoCount += voteWeight;
     }
}