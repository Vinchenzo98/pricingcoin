// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./harvestLossLibrary.sol";
import "./calculateBaseLibrary.sol";
import "./sqrtLibrary.sol";

contract PpContract is ERC20 {
    
    using calculateBaseLibrary for *;
    using sqrtLibrary for *;
    using harvestLossLibrary for *;
    
    //Initial constructor for the entire Pricing Protocol contract
    constructor(uint256 initialSupply) ERC20("PricingCoin", "PP") {
        _mint(msg.sender, initialSupply);
        nonce = 1;
    }
    
    // ============ Mutable storage ============
    //tracks total profit generated during life of protocol
    uint profitGenerated;
    //tracks total amount of coins generated during life of protocol
    uint totalCoinsIssued;
    //tracks the current nonce (i.e. number lossPoolDistribution session)
    uint nonce;
    
    //Total amount of NFTs that have been priced using pricing protocol
    address[] nftAddresses;
    //Keep track of all unique coin holder addresses 
    address[] coinHolders; 
    
    // ============ Mappings ============
    //Mapping to check if a user is already considered a coin holder
    mapping(address => bool) isCoinHolder;
    //Maps the total appraisal value to an NFT address to be used for mapping finalAppraisal to specific NFT address
    mapping(address => uint) totalAppraisalValue;
    //Mapping used to track how many voters have voted on a particular NFT
    mapping(address => address[]) addressesPerNft;
    //Easily accesible pricing session lookup 
    mapping(address => PricingSession) AllPricingSessions;
    //Allows pricing protocol to handle multiple NFTs at once by allowing lookup and tracking of different NFTs
    mapping(address => mapping (address => Voter)) nftVotes;
    //Allow contract to track which NFT sessions a user has participated in
    mapping(address => address[]) userSessionsParticipated;
    //Track specific lPDS (at current nonce) holdings
    mapping(uint => uint) lossPoolDistributionSession;
    //Used to limit user lossPool claims to 1 per rounds
    mapping(uint => mapping(address => bool)) lossPoolAccessCheck;
    //Used to track start time of distribution session 
    mapping(uint => uint) lPDSstartTime;
    
    // ============ Structs ============
    //Voter struct to allow users to submit votes, stake, and track that the user has already voted (i.e. exists = true) 
    struct Voter {
        /*
        Base --> base amount of tokens that equation for distibution will be based on. 
        Detemined by raw appraisal accuracy
        */
        uint base;
        //Voter appraisal 
        uint appraisal;
        //Voter stake
        uint stake;
        //Used to stop voters from entering multiple times from same address
        bool exists;
    }
    
    //Keeps track of important data from each pricing session in the form of an item
    struct PricingSession {
        //Sesssion start time
        uint startTime;
        //Session end time is 1 day after start time
        uint endTime;
        //Final appraisal calculated using --> weight per user * appraisal per user
        uint finalAppraisal;
        //Keep track of amount of unique voters (by address) in pricing session
        uint uniqueVoters;
        //Keep track of totalVotes (takes into account multiple votes attributed during weighting)
        uint totalVotes;
        //Track the amount of tokens issued in each pricing session
        uint tokensIssued;
        //Tracks lossPoolTotal in each pricing session
        uint lossPoolTotal;
        //Tracks total session stake
        uint totalSessionStake;
        //Track lowest stake, for vote weighting
        uint lowestStake;
        //Track amount of votes that have been weighted
        uint amountVotesWeighted;
        //Track amount of bases calculated
        uint amountBasesCalculated;
        //track amount of coin issue events 
        uint coinIssueEvents;
        //track amount of loss harvest events
        uint lossHarvestEvents;
        //Track existence of NFT session
        bool active;
        //Bools to force specific progression of actions and allow users to call functions
        bool votesWeighted;
        bool finalAppraisalSet;
        bool baseCalculated;
        bool coinsIssued;
        bool lossHarvested;
    }
    
    // ============ Events ============
    //Emit sessino creation event
    event sessionCreated(uint startTime, uint endTime, address _nftAddress);
    //Represents a new vote being created
    event newVoteCreated(address _nftAddress, address _voterAddress, uint appraisal, uint stake);
    //Event to show that a session ended.
    event sessionOver(address _nftAddress, uint endTime);
    //Represents the ending of pricing session and a final appraisal being determined 
    event finalAppraisalDetermined(address _nftAddress, uint appraisal, uint amountVoters);
    //Log coins being issued to user
    event coinsIssued(uint _amount, address recipient);
    //Log stakes successfully being refunded
    event stakeRefunded(uint _amount, address recipient);
    //Log lossPool successfully being distributed
    event lossPoolDistributed(uint _amount, address recipient);
    
    // ============ Modifiers ============
    //Check if contract is still currently active 
    modifier isActive(address _nftAddress) {
        //If block.timestamp is less than endTime the session is over so user shouldn't be able to vote anymore
        require(block.timestamp < AllPricingSessions[_nftAddress].endTime, "PNA");
        _;
    }
    
    //Enforce session buffer to stop sessions from getting overwritten
    modifier stopOverwrite(address _nftAddress) {
        require(AllPricingSessions[_nftAddress].active = false 
            && block.timestamp > AllPricingSessions[_nftAddress].endTime + 10 days, "W8D");
        _;
    }
    
    //Make sure users don't submit more than one appraisal
    modifier oneVoteEach(address _nftAddress) {
        require(!nftVotes[_nftAddress][msg.sender].exists, "1V");
        _;
    }
    
    //Check to see that the user has enough money to stake what they promise
    modifier checkStake {
        require(msg.value >= 0.001 ether, "SETH");
        _;
    }
    
    //The following 7 modifiers enforce the proper progression of a session 
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

    modifier baseCalculatedComplete(address _nftAddress) {
        require(AllPricingSessions[_nftAddress].baseCalculated == true ||
            block.timestamp > AllPricingSessions[_nftAddress].endTime + 2 days, "WBC");
        _;
    }
    
    modifier coinsIssuedComplete(address _nftAddress) {
        require(AllPricingSessions[_nftAddress].coinsIssued == true ||
            block.timestamp > AllPricingSessions[_nftAddress].endTime + 4 days, "WCI");
        _;
    }

    modifier lossHarvestedComplete(address _nftAddress) {
        require(AllPricingSessions[_nftAddress].lossHarvested == true ||
            block.timestamp > AllPricingSessions[_nftAddress].endTime + 4 days, "WLH");
        _;
    }
    
    //Create a new pricing session
    function createPricingSession(address _nftAddress) stopOverwrite(_nftAddress) public {
        //Create new instance of PricingSession
        PricingSession memory newSession;
        //Assign new instance to NFT address
        AllPricingSessions[_nftAddress] = newSession;
        //Set start time of pricing session
        AllPricingSessions[_nftAddress].startTime = block.timestamp;
        //Set end time of pricing session
        AllPricingSessions[_nftAddress].endTime = block.timestamp + 1 days;
        //Set initial super high lowest stake so its inevitably overwritten
        AllPricingSessions[_nftAddress].lowestStake = 10000000 ether;
        //Switch pricing session to active 
        AllPricingSessions[_nftAddress].active = true;
        //Add new NFT address to list of addresses 
        nftAddresses.push(_nftAddress);
        emit sessionCreated(block.timestamp, block.timestamp + 1 days, _nftAddress);
    }
    
    /* 
    This function allows users to create a new vote for an NFT. 
    */
    function setVote(uint _appraisal, address _nftAddress) checkStake isActive(_nftAddress) oneVoteEach(_nftAddress) payable public {
        //Create a new Voter instance
        Voter memory newVote = Voter(0, _appraisal, msg.value, true);
        if (msg.value < AllPricingSessions[_nftAddress].lowestStake) {
            AllPricingSessions[_nftAddress].lowestStake = msg.value;
        }
        //Add to total appraisal value for final appraisal calculation
        totalAppraisalValue[_nftAddress] += _appraisal;
        AllPricingSessions[_nftAddress].totalVotes ++;
        //Add to total session stake to for reward purposes later on in issueCoin equation
        AllPricingSessions[_nftAddress].totalSessionStake += msg.value;
        //Attach new msg.sender address to newVote (i.e. new Voter struct)
        nftVotes[_nftAddress][msg.sender] = newVote;
        //Add voter to addressesPerNft for tracking unique voters
        addressesPerNft[_nftAddress].push(msg.sender);
        //Update sessions participated for user look up ability
        userSessionsParticipated[msg.sender].push(_nftAddress);
        emit newVoteCreated(_nftAddress, msg.sender, _appraisal, msg.value);
    }
    
     /* 
    Each vote is weighted based on the lowest stake. So lowest stake starts as 1 vote 
    and the rest of the votes are weighted as a multiple of that. Eq --> sqrt(stake/lowestStake)
    */
    function weightVote(address _nftAddress) votingSessionComplete(_nftAddress) public {
        if(block.timestamp > AllPricingSessions[_nftAddress].endTime + 1 days) {
            AllPricingSessions[_nftAddress].votesWeighted = true;
        }
        require(AllPricingSessions[_nftAddress].votesWeighted == false);
        //Weighting user at <address a> vote based on lowestStake
        uint weight = sqrtLibrary.sqrt(nftVotes[_nftAddress][msg.sender].stake/AllPricingSessions[_nftAddress].lowestStake);
        //Add weighted amount of votes to PricingSession total votes for calculating setFinalAppraisal
        AllPricingSessions[_nftAddress].totalVotes += weight-1;
        //weight - 1 since one instance was already added in initial setVote function
        totalAppraisalValue[_nftAddress] += (weight-1) * nftVotes[_nftAddress][msg.sender].appraisal;
        //Track to end session
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
        //requires that the finalAppraisal has not been set yet
        require(AllPricingSessions[_nftAddress].finalAppraisalSet == false);
        //If a session is larger than 40 people, the user that trigers the final Appraisal is awarded 2 tokens.
        if(addressesPerNft[_nftAddress].length >= 40) {
            _mint(msg.sender, 2);
        }
        //Set amountOfVoters for tracking unique voters in a pricing session
        AllPricingSessions[_nftAddress].uniqueVoters = addressesPerNft[_nftAddress].length;
        //Set finalAppraisal by calculating totalAppraisalValue / totalVotes. Scale back the 1000 to make up for scaling method in setVote
        AllPricingSessions[_nftAddress].finalAppraisal = (totalAppraisalValue[_nftAddress])/(AllPricingSessions[_nftAddress].totalVotes);
        nftAddresses.push(_nftAddress);
        //End pricingSession
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

    Refer to calculateBaseLibrary on github for implementation
    */

    function calculateBase(address _nftAddress) finalAppraisalComplete(_nftAddress) public {
        //Set consequence for users that don't calculate their base before the window closes
        nftVotes[_nftAddress][msg.sender].base = 0;
        require(AllPricingSessions[_nftAddress].baseCalculated == false &&
            !(block.timestamp > AllPricingSessions[_nftAddress].endTime + 2 days));
        /*
        Each of the following test the voters guess starting from 105 (5% above) and going down to 95 (5% below). 
        If true nftVotes[_nftAddress][a].base is set to reflect the users base reward
        */
        
        //Calculates users base reward (Reference library implementation)
        nftVotes[_nftAddress][msg.sender].base = 
            calculateBaseLibrary.calculateBase(
                AllPricingSessions[_nftAddress].finalAppraisal, 
                nftVotes[_nftAddress][msg.sender].appraisal
                );
    }
    
       /*
    Distribution formula --> 
    Four factors:  size of pricing session (constant for all in session), 
                   size of total staking pool (constant for all in session),    
                   user stake (quadratic multiplier),  
                   accuracy (base)
    Equation = base * sqrt(personal stake) * sqrt(size of pricing session) * sqrt(total ETH in staking pool)
    */
    function issueCoins(address _nftAddress) public baseCalculatedComplete(_nftAddress) returns(bool){
        require(AllPricingSessions[_nftAddress].coinsIssued == false &&
            block.timestamp < AllPricingSessions[_nftAddress].endTime + 4 days);
        uint amount; 
        //If pricing session size is under 20 users participants receive no reward, to stop users from making obscure pricing sessions
        if (addressesPerNft[_nftAddress].length < 20) {
            amount = 0;
        }
        //If pricing session is 20 or larger then the pricing equation kicks in
        else if (addressesPerNft[_nftAddress].length >= 20) {
            amount = (nftVotes[_nftAddress][msg.sender].base * sqrtLibrary.sqrt(nftVotes[_nftAddress][msg.sender].stake) * sqrtLibrary.sqrt(addressesPerNft[_nftAddress].length) * 
                sqrtLibrary.sqrt(AllPricingSessions[_nftAddress].totalSessionStake)/sqrtLibrary.sqrt(10**18))/sqrtLibrary.sqrt(10**18);
        }
        //Mints the coins based on earned tokens and sends them to user at address a
        _mint(msg.sender, amount);
        totalCoinsIssued += amount;
        /*
        If user is not a coinHolder (i.e. isCoinHolder[a] is false) 
        this should push them to coinHolders list and set isCoinHolder to true.
        */
        if (isCoinHolder[msg.sender] = false) {
            //Added user to coinHolder list for coin distribution purposes
            coinHolders.push(msg.sender);
            //Recognize this holder has been added to the list
            isCoinHolder[msg.sender] = true;
        }
        //Adds to total tokens issued
        AllPricingSessions[_nftAddress].tokensIssued += amount;
        AllPricingSessions[_nftAddress].coinIssueEvents++;
        
        if (AllPricingSessions[_nftAddress].coinIssueEvents == addressesPerNft[_nftAddress].length){
            AllPricingSessions[_nftAddress].coinsIssued = true;
        }
        else {
            AllPricingSessions[_nftAddress].coinsIssued = false;
        }
        emit coinsIssued(amount, msg.sender);
        //returns true if function ran smoothly and correctly executed
        return true;
    }
    
    /*
    At conclusion of pricing session we harvest the losses of users
    that made guesses outside of the 5% over/under the finalAppraisalPrice
    
    Should return amount total loss harvest amount 
    */
    function harvestLoss(address _nftAddress) coinsIssuedComplete(_nftAddress) public {
        require(AllPricingSessions[_nftAddress].lossHarvested == true &&
            block.timestamp < AllPricingSessions[_nftAddress].endTime + 6 days);
       /*
       Checks users that are out of the money for how far over (in first if statement) 
       or under (in else if) they are and adjusts their stake balance accordingly
       */
        require(nftVotes[_nftAddress][msg.sender].stake > 0);
        if (nftVotes[_nftAddress][msg.sender].appraisal*100 > 105*AllPricingSessions[_nftAddress].finalAppraisal){
            //Harvests loss for users that priced higher than 5% above finalAppraisal
            uint totalHarvestedOver= harvestLossLibrary.harvestUserOver(
                nftVotes[_nftAddress][msg.sender].stake, 
                nftVotes[_nftAddress][msg.sender].appraisal, 
                AllPricingSessions[_nftAddress].finalAppraisal
                );
                
            AllPricingSessions[_nftAddress].lossPoolTotal += totalHarvestedOver;
            nftVotes[_nftAddress][msg.sender].stake = 
                nftVotes[_nftAddress][msg.sender].stake - totalHarvestedOver;
            lossPoolDistributionSession[nonce] += totalHarvestedOver;
            profitGenerated += totalHarvestedOver;
            
            //Send stake back and emit event confirming
            payable(msg.sender).transfer(nftVotes[_nftAddress][msg.sender].stake);
            nftVotes[_nftAddress][msg.sender].stake = 0;
            emit stakeRefunded(nftVotes[_nftAddress][msg.sender].stake, msg.sender);
        }
        else if(nftVotes[_nftAddress][msg.sender].appraisal*100 < 95*AllPricingSessions[_nftAddress].finalAppraisal){
            //Harvests loss for users that priced lower than 5% below finalAppraisal 
            uint totalHarvestedUnder = harvestLossLibrary.harvestLossUnder(
                nftVotes[_nftAddress][msg.sender].stake, 
                nftVotes[_nftAddress][msg.sender].appraisal, 
                AllPricingSessions[_nftAddress].finalAppraisal
                );
                
            AllPricingSessions[_nftAddress].lossPoolTotal += totalHarvestedUnder;
            nftVotes[_nftAddress][msg.sender].stake = 
                nftVotes[_nftAddress][msg.sender].stake - totalHarvestedUnder;
            lossPoolDistributionSession[nonce] += totalHarvestedUnder;
            profitGenerated += totalHarvestedUnder;
                
            //Send stake back and emit event confirming
            payable(msg.sender).transfer(nftVotes[_nftAddress][msg.sender].stake);
            nftVotes[_nftAddress][msg.sender].stake = 0;
            emit stakeRefunded(nftVotes[_nftAddress][msg.sender].stake, msg.sender);
        }
        else {
            //Send stake back and emit event confirming
            payable(msg.sender).transfer(nftVotes[_nftAddress][msg.sender].stake);
            nftVotes[_nftAddress][msg.sender].stake = 0;
            emit stakeRefunded(nftVotes[_nftAddress][msg.sender].stake, msg.sender);
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
    function distributeLossPool() public returns(bool){
        //Make sure the msg.sender hasn't drawn from this session yet, its 30 days after last session, session still has ETH
        require(lossPoolAccessCheck[nonce][msg.sender] == false 
            && lPDSstartTime[nonce] >= lPDSstartTime[nonce - 1] + 32 days 
            && lossPoolDistributionSession[nonce] > 0);
        //Receiver is any owner of a $PP. Splits up contract balance and multiplies share per coin by user balancOf coins
        lossPoolAccessCheck[nonce][msg.sender] = true;
        //Send msg.sender their portion of the loss pool
        payable(msg.sender).transfer(balanceOf(msg.sender) * lossPoolDistributionSession[nonce]/totalSupply());
        //Adjust lossPool balance to reflect ^^ transaction
        lossPoolDistributionSession[nonce] -= balanceOf(msg.sender) * lossPoolDistributionSession[nonce]/totalSupply();
        emit lossPoolDistributed(balanceOf(msg.sender) * lossPoolDistributionSession[nonce]/totalSupply(), msg.sender);
        
        //Check if session has been completely drawn down, or the session has passed its time limit if either is true end the session
        if (lossPoolDistributionSession[nonce] == 0 || lPDSstartTime[nonce] + 2 days < block.timestamp){
            nonce++;
            lossPoolDistributionSession[nonce] += lossPoolDistributionSession[nonce - 1];
            lossPoolDistributionSession[nonce - 1] = 0;
        }
        
        return true;
    }
    
    function getLossPoolRemainder() view public returns(uint) {
        return lossPoolDistributionSession[nonce];
    }
    
    function getProfitsGenerated() view public returns(uint) {
        return profitGenerated;
    }
    
    function getTotalCoinsIssued() view public returns(uint) {
        return totalSupply();
    }
    
    function getTotalSessionStake(address _nftAddress) view public returns(uint) {
        return AllPricingSessions[_nftAddress].totalSessionStake;
    }
    
    function getEndTime(address _nftAddress) view public returns(uint) {
        return AllPricingSessions[_nftAddress].endTime;
    }
    
    function getTotalVoters(address _nftAddress) view public returns(uint) {
        return addressesPerNft[_nftAddress].length;
    }
    
    function getVote(address _nftAddress) view public returns(uint) {
        return nftVotes[_nftAddress][msg.sender].appraisal;
    }
    
    function getStake(address _nftAddress) view public returns(uint) {
        return nftVotes[_nftAddress][msg.sender].stake;
    }
    
    function getFinalAppraisal(address _nftAddress) view public returns(uint) {
        return AllPricingSessions[_nftAddress].finalAppraisal;
    } 
}