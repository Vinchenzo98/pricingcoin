// SPDX-License-Identifier: GPL-3.0

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./PpCompute.sol";

pragma solidity >=0.4.22 <0.9.0;

contract PpMaster is ERC20, PpCompute {
    
    //Mapping to check if a user is already considered a coin holder
    mapping(address => bool) isCoinHolder;
    //Keep track of all unique coin holder addresses 
    address[] coinHolders; 
    
    //Initial constructor for the entire Pricing Protocol contract
    constructor(uint256 initialSupply) ERC20("PricingCoin", "PP") {
        _mint(msg.sender, initialSupply);
    }
    
    modifier baseCalculatedComplete(address _nftAddress) {
        require(AllPricingSessions[_nftAddress].baseCalculated == true ||
            block.timestamp > AllPricingSessions[_nftAddress].endTime + 2 days, "Wait until base is calculated.");
        _;
    }
    
    modifier coinsIssuedComplete(address _nftAddress) {
        require(AllPricingSessions[_nftAddress].coinsIssued == true ||
            block.timestamp > AllPricingSessions[_nftAddress].endTime + 4 days, "Wait until base is calculated.");
        _;
    }

    modifier lossHarvestedComplete(address _nftAddress) {
        require(AllPricingSessions[_nftAddress].lossHarvested == true ||
            block.timestamp > AllPricingSessions[_nftAddress].endTime + 4 days, "Wait until base is calculated.");
        _;
    }
    
    modifier lossDistributedComplete(address _nftAddress) {
        require(AllPricingSessions[_nftAddress].lossPoolDistributed == true ||
            block.timestamp > AllPricingSessions[_nftAddress].endTime + 6 days, "Wait until base is calculated.");
        _;
    }
    
    /*
    Distribution formula --> 
    Four factors:  size of pricing session (constant for all in session), 
                   size of total staking pool (constant for all in session),    
                   user stake (quadratic multiplier),  
                   accuracy (base)
    Equation = base * sqrt(personal stake) * sqrt(size of pricing session) * sqrt(total ETH in staking pool)
    Base Distribution:
    */
    function issueCoins(address a, address _nftAddress) public baseCalculatedComplete(_nftAddress) returns(bool){
        require(AllPricingSessions[_nftAddress].coinsIssued == false &&
            !(block.timestamp > AllPricingSessions[_nftAddress].endTime + 4 days));
        uint amount; 
        //If pricing session size is under 20 users participants receive no reward, to stop users from making obscure pricing sessions
        if (addressesPerNft[_nftAddress].length < 20) {
            amount = 0;
        }
        //If pricing session is 20 or larger then the pricing equation kicks in
        else if (addressesPerNft[_nftAddress].length >= 20) {
            amount = (nftVotes[_nftAddress][a].base * sqrt(nftVotes[_nftAddress][a].stake) * sqrt(addressesPerNft[_nftAddress].length) * 
                sqrt(AllPricingSessions[_nftAddress].totalSessionStake)/sqrt(10**18))/sqrt(10**18);
        }
        //Mints the coins based on earned tokens and sends them to user at address a
        _mint(a, amount);
        /*
        If user is not a coinHolder (i.e. isCoinHolder[a] is false) 
        this should push them to coinHolders list and set isCoinHolder to true.
        */
        if (isCoinHolder[a] = false) {
            //Added user to coinHolder list for coin distribution purposes
            coinHolders.push(a);
            //Recognize this holder has been added to the list
            isCoinHolder[a] = true;
        }
        //Adds to total tokens issued
        AllPricingSessions[_nftAddress].tokensIssued += amount;
        AllPricingSessions[_nftAddress].coinIssueEvent++;
        
        if (AllPricingSessions[_nftAddress].coinIssueEvent == addressesPerNft[_nftAddress].length){
            AllPricingSessions[_nftAddress].coinsIssued = true;
        }
        else {
            AllPricingSessions[_nftAddress].coinsIssued = false;
        }
        emit coinsIssued(amount, a);
        //returns true if function ran smoothly and correctly executed
        return true;
    }
    
    /*
    At conclusion of pricing session we harvest the losses of users
    that made guesses outside of the 5% over/under the finalAppraisalPrice
    
    Should return amount total loss harvest amount 
    */
    function harvestLoss(address a, address _nftAddress) coinsIssuedComplete(_nftAddress) public {
        require(AllPricingSessions[_nftAddress].lossHarvested == true &&
            !(block.timestamp > AllPricingSessions[_nftAddress].endTime + 4 days));
       /*
       Checks users that are out of the money for how far over (in first if statement) 
       or under (in else if) they are and adjusts their stake balance accordingly
       */
        require(nftVotes[_nftAddress][a].stake > 0);
        if (nftVotes[_nftAddress][a].appraisal*100 > 105*AllPricingSessions[_nftAddress].finalAppraisal){
            AllPricingSessions[_nftAddress].lossPoolTotal += nftVotes[_nftAddress][a].stake * (nftVotes[_nftAddress][a].appraisal*100 - 105*AllPricingSessions[_nftAddress].finalAppraisal)
                /(AllPricingSessions[_nftAddress].finalAppraisal*100);
            nftVotes[_nftAddress][a].stake = 
                (nftVotes[_nftAddress][a].stake - nftVotes[_nftAddress][a].stake * (nftVotes[_nftAddress][a].appraisal*100 - 105*AllPricingSessions[_nftAddress].finalAppraisal)
                /(AllPricingSessions[_nftAddress].finalAppraisal*100));
            //Send stake back and emit event confirming
            payable(a).transfer(nftVotes[_nftAddress][a].stake);
            nftVotes[_nftAddress][a].stake = 0;
            emit stakeRefunded(nftVotes[_nftAddress][a].stake, a);
        }
        else if(nftVotes[_nftAddress][a].appraisal*100 < 95*AllPricingSessions[_nftAddress].finalAppraisal){
            AllPricingSessions[_nftAddress].lossPoolTotal += nftVotes[_nftAddress][a].stake * (95*AllPricingSessions[_nftAddress].finalAppraisal - 100*nftVotes[_nftAddress][a].appraisal)
                /(AllPricingSessions[_nftAddress].finalAppraisal*100);
            nftVotes[_nftAddress][a].stake = 
                (nftVotes[_nftAddress][a].stake - nftVotes[_nftAddress][a].stake * (95*AllPricingSessions[_nftAddress].finalAppraisal - 100*nftVotes[_nftAddress][a].appraisal)
                /(AllPricingSessions[_nftAddress].finalAppraisal*100));
            //Send stake back and emit event confirming
            payable(a).transfer(nftVotes[_nftAddress][a].stake);
            nftVotes[_nftAddress][a].stake = 0;
            emit stakeRefunded(nftVotes[_nftAddress][a].stake, a);
        }
        else {
            //Send stake back and emit event confirming
            payable(a).transfer(nftVotes[_nftAddress][a].stake);
            nftVotes[_nftAddress][a].stake = 0;
            emit stakeRefunded(nftVotes[_nftAddress][a].stake, a);
        }
        AllPricingSessions[_nftAddress].lossHarvestEvents++;
        
        if (AllPricingSessions[_nftAddress].lossHarvestEvents == addressesPerNft[_nftAddress].length){
            AllPricingSessions[_nftAddress].lossHarvested = true;
        }
        else {
            AllPricingSessions[_nftAddress].lossHarvested = false;
        }
        
    }    
    
    /*
    Loss pool should be divided by the amount of tokens in circulation and
    distributed to each coin holder wallet. For example if loss pool held 10 
    eth and there were 10 coins in circulation each coin would recieve 0.1 eth.
    
    Should return true if loss pool is completely distributed.
    
    balancOf(a) represents the user (address a) balance of $PP.
    _amount represents the calculate amount of ETH per token that is to be distributed.
    Function should return true if eth is successfully sent. 
    */
    function distributeLossPool(address payable receiver, address _contract) 
        public lossHarvestedComplete(_nftAddress) returns(bool){
            require(accessedLossPool[receiver] == false);
        //Receiver is any owner of a $PP. Splits up contract balance and multiplies share per coin by user balancOf coins
        accessedLossPool[receiver] == true;
        receiver.transfer(balanceOf(receiver) * _contract.balance/totalSupply());
        emit lossPoolDistributed(balanceOf(receiver) * _contract.balance/totalSupply(), receiver);
        AllPricingSessions[_nftAddress].distributionEvents++;
        
        if (AllPricingSessions[_nftAddress].distributionEvents == addressesPerNft[_nftAddress].length){
            AllPricingSessions[_nftAddress].lossPoolDistributed = true;
        }
        else {
            AllPricingSessions[_nftAddress].lossPoolDistributed = false;
        }
        
        return true;
    }
    
    function getTotalSessionStake(address _nftAddress) view public returns(uint) {
        return AllPricingSessions[_nftAddress].totalSessionStake;
    }
    
    function getEndTime(address _nftAddress) view public returns(uint) {
        return AllPricingSessions[_nftAddress].endTime;
    }
    
    function getTimeLeft(address _nftAddress) public returns(uint) {
        uint timeLeft;
        if(AllPricingSessions[_nftAddress].endTime > block.timestamp) {
            timeLeft = AllPricingSessions[_nftAddress].endTime - block.timestamp;
        }
        else {
            timeLeft = 0;
            //If session is over, this event will tell front end to kick off post session ops
            emit sessionOver(_nftAddress, AllPricingSessions[_nftAddress].endTime);
        }
        return timeLeft;
    }
    
    function getTotalVoters(address _nftAddress) view public returns(uint) {
        return addressesPerNft[_nftAddress].length;
    }
    
    function getTreasury(address a) view public returns(uint) {
        return a.balance;
    }
    
    function getVote(address a, address _nftAddress) view public onlyOwner returns(uint) {
        return nftVotes[_nftAddress][a].appraisal;
    }
    
    function getStake(address _nftAddress) view public onlyOwner returns(uint) {
        return nftVotes[_nftAddress][msg.sender].stake;
    }
    
    function getFinalAppraisal(address _nftAddress) view public returns(uint) {
        return AllPricingSessions[_nftAddress].finalAppraisal;
    } 
}



