// SPDX-License-Identifier: GPL-3.0

import "@openzeppelin/contracts/access/Ownable.sol";
import "./PpAllowVoting.sol";
import "./calculateBaseLibrary.sol";
import "./sqrtLibrary.sol";

pragma solidity >=0.4.22 <0.9.0;

contract PpCompute is PpVoting, Ownable {
    
    using calculateBaseLibrary for *;
    using sqrtLibrary for *;

    //Event to show that a session ended.
    event sessionOver(address _nftAddress, uint endTime);
    //Represents the ending of pricing session and a final appraisal being determined 
    event finalAppraisalDetermined(address _nftAddress, uint appraisal, uint amountVoters);
    
    modifier votingSessionComplete(address _nftAddress) {
        require(block.timestamp >= AllPricingSessions[_nftAddress].endTime, "PSO");
        _;
    }
    
    modifier votesWeightedComplete(address _nftAddress) {
        require(AllPricingSessions[_nftAddress].votesWeighted == true || 
            block.timestamp > AllPricingSessions[_nftAddress].endTime + 1 days, "WVW"); 
        _;
    }
    
    modifier finalAppraisalComplete(address _nftAddress) {
        require(AllPricingSessions[_nftAddress].finalAppraisalSet == true, "WFA");
        _;
    }
    
    /* 
    Each vote is weighted based on the lowest stake. So lowest stake starts as 1 vote 
    and the rest of the votes are weighted as a multiple of that. 
    */
    function weightVote(address _nftAddress) votingSessionComplete(_nftAddress) public {
        require(AllPricingSessions[_nftAddress].votesWeighted == false);
        //Weighting user at <address a> vote based on lowestStake
        uint weight = sqrtLibrary.sqrt(nftVotes[_nftAddress][msg.sender].stake/AllPricingSessions[_nftAddress].lowestStake);
        //Add weighted amount of votes to PricingSession total votes for calculating setFinalAppraisal
        AllPricingSessions[_nftAddress].totalVotes += weight-1;
        //weight - 1 since one instance was already added in initial setVote function
        totalAppraisalValue[_nftAddress] += (weight-1) * nftVotes[_nftAddress][msg.sender].appraisal;
        AllPricingSessions[_nftAddress].amountVotesWeighted ++;
        if (AllPricingSessions[_nftAddress].amountVotesWeighted == addressesPerNft[_nftAddress].length){
            AllPricingSessions[_nftAddress].votesWeighted = true;
        }
        else {
            AllPricingSessions[_nftAddress].votesWeighted = false;
        }
    }
    
    /*
    Function used to set the final appraisal of a pricing session
    */
    function setFinalAppraisal(address _nftAddress) votesWeightedComplete(_nftAddress) public {
        require(AllPricingSessions[_nftAddress].finalAppraisalSet == false);
        //Set amountOfVoters for tracking unique voters in a pricing session
        AllPricingSessions[_nftAddress].uniqueVoters = addressesPerNft[_nftAddress].length;
        //Set finalAppraisal by calculating totalAppraisalValue / totalVotes. Scale back the 1000 to make up for scaling method in setVote
        AllPricingSessions[_nftAddress].finalAppraisal = (totalAppraisalValue[_nftAddress])/(AllPricingSessions[_nftAddress].totalVotes);
        nftAddresses.push(_nftAddress);
        AllPricingSessions[_nftAddress].active = false;
        AllPricingSessions[_nftAddress].finalAppraisalSet = true;
        emit finalAppraisalDetermined(_nftAddress, AllPricingSessions[_nftAddress].finalAppraisal, AllPricingSessions[_nftAddress].uniqueVoters);
    }
    
    /*
    At conclusion of pricing session we issue coins to users within ___ of price:
    
    Four factors:  size of pricing session (constant for all in session), 
                   size of total staking pool (constant for all in session),    
                   user stake (quadratic multiplier),  
                   accuracy (base)
    Equation = base * sqrt(personal stake) * sqrt(size of pricing session) * sqrt(total ETH in staking pool)
    Base Distribution:
        - 1% --> 5 $PP
        - 2% --> 4 $PP
        - 3% --> 3 $PP
        - 4% --> 2 $PP
        - 5% --> 1 $PP
        
    Should return true if the coins were issued correctly
    
    This logic is implemented in calculateBase and issueCoins functions
    */

    function calculateBase(address _nftAddress) finalAppraisalComplete(_nftAddress) public {
        nftVotes[_nftAddress][msg.sender].base = 0;
        require(AllPricingSessions[_nftAddress].baseCalculated == false &&
            !(block.timestamp > AllPricingSessions[_nftAddress].endTime + 2 days));
        /*
        Each of the following test the voters guess starting from 105 (5% above) and going down to 95 (5% below). 
        If true nftVotes[_nftAddress][a].base is set to reflect the users base reward
        */
        
        nftVotes[_nftAddress][msg.sender].base = 
            calculateBaseLibrary.calculateBase(
                AllPricingSessions[_nftAddress].finalAppraisal, 
                nftVotes[_nftAddress][msg.sender].appraisal
                );

        if (nftVotes[_nftAddress][msg.sender].base > 0) {
            AllPricingSessions[_nftAddress].inTheMoney.push(msg.sender);
        }
        else {
            AllPricingSessions[_nftAddress].outTheMoney.push(msg.sender);
        }
        
    }
}
