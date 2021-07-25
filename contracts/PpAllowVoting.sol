// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.4.22 <0.9.0;

contract PpVoting {
    //Maps the total appraisal value to an NFT address to be used for mapping finalAppraisal to specific NFT address
    mapping(address => uint) totalAppraisalValue;
    
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
    
    //Mapping used to track how many voters have voted on a particular NFT
    mapping(address => address[]) addressesPerNft;
    
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
        uint amountBasesCalculated;
        uint coinIssueEvents;
        uint lossHarvestEvents;
        uint distributionEvents;
        //Track existence of NFT session
        bool active;
        //Bools to force specific progression of actions and allow users to call functions
        bool votesWeighted;
        bool finalAppraisalSet;
        bool baseCalculated;
        bool coinsIssued;
        bool lossHarvested;
        bool lossPoolDistributed;
        //Track out of the money addresses to optimize amount of transactions when harvesting loss
        address[] outTheMoney;
        //Track in the money addresses to optimize amount of transactions when paying out
        address[] inTheMoney;
    }
    
    //Easily accesible pricing session lookup 
    mapping(address => PricingSession) AllPricingSessions;
    //Total amount of NFTs that have been priced using pricing protocol
    address[] nftAddresses;
    //Allows pricing protocol to handle multiple NFTs at once by allowing lookup and tracking of different NFTs
    mapping(address => mapping (address => Voter)) nftVotes;
    
    //Emit sessino creation event
    event sessionCreated(uint startTime, uint endTime, address _nftAddress);
    //Represents a new vote being created
    event newVoteCreated(address _nftAddress, address _voterAddress, uint appraisal, uint stake);
    
        //Check if contract is still currently active 
    modifier isActive(address _nftAddress) {
        //If block.timestamp is less than endTime the session is over so user shouldn't be able to vote anymore
        require(block.timestamp < AllPricingSessions[_nftAddress].endTime, "This pricing session is no longer active :(");
        _;
    }
    
    //Enforce session buffer to stop sessions from getting overwritten
    modifier stopOverwrite(address _nftAddress) {
        require(AllPricingSessions[_nftAddress].active = false 
            && block.timestamp > AllPricingSessions[_nftAddress].endTime + 8 days, "You must wait 8 days before creating new session for this NFT.");
        _;
    }
    
    //Make sure users don't submit more than one appraisal
    modifier oneVoteEach(address _nftAddress) {
        require(!nftVotes[_nftAddress][msg.sender].exists, "Each user only gets one vote!");
        _;
    }
    
    //Check to see that the user has enough money to stake what they promise
    modifier checkStake {
        require(msg.value >= 0.001 ether, "You must stake some ETH to vote :)");
        _;
    }
    
    //Create a new pricing session
    function createPricingSession(address _nftAddress) stopOverwrite(_nftAddress) public {
        //Create new instance of PricingSession
        PricingSession memory newSession;
        //Assign new instance to NFT address
        AllPricingSessions[_nftAddress] = newSession;
        AllPricingSessions[_nftAddress].startTime = block.timestamp;
        AllPricingSessions[_nftAddress].endTime = block.timestamp + 1 days;
        AllPricingSessions[_nftAddress].lowestStake = 10000000 ether;
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
        totalAppraisalValue[_nftAddress] += _appraisal;
        AllPricingSessions[_nftAddress].totalVotes ++;
        //Add to total session stake to for reward purposes later on in issueCoin equation
        AllPricingSessions[_nftAddress].totalSessionStake += msg.value;
        //Attach new msg.sender address to newVote (i.e. new Voter struct)
        nftVotes[_nftAddress][msg.sender] = newVote;
        addressesPerNft[_nftAddress].push(msg.sender);
        emit newVoteCreated(_nftAddress, msg.sender, _appraisal, msg.value);
    }
    
}

