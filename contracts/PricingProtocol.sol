// SPDX-License-Identifier: GPL-3.0

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

pragma solidity >=0.4.22 <0.9.0;

contract PricingProtocol is ERC20{
    //Manager --> Creator of the contract 
    address public manager;
    
    //Maps the total appraisal value to an NFT address to be used for mapping finalAppraisal to specific NFT address
    mapping(address => uint) totalAppraisalValue;
    
    //Initial constructor for the entire Pricing Protocol contract
    constructor(uint256 initialSupply) ERC20("PricingCoin", "PP") {
        _mint(msg.sender, initialSupply);
        manager = msg.sender;
    }
    
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
        //Track existence of NFT session
        bool active;
    }
    
    //Easily accesible pricing session lookup 
    mapping(address => PricingSession) AllPricingSessions;
    //Total amount of NFTs that have been priced using pricing protocol
    address[] nftAddresses;
    //Allows pricing protocol to handle multiple NFTs at once by allowing lookup and tracking of different NFTs
    mapping(address => mapping (address => Voter)) nftVotes;
    //Track in the money addresses to optimize amount of transactions when paying out
    address[] inTheMoney;
    //Track out of the money addresses to optimize amount of transactions when harvesting loss
    address[] outTheMoney;
    //Mapping to check if a user is already considered a coin holder
    mapping(address => bool) isCoinHolder;
    //Keep track of all unique coin holder addresses 
    address[] coinHolders; 
    
    //Emit sessino creation event
    event sessionCreated(uint startTime, uint endTime, address _nftAddress);
    //Represents a new vote being created
    event newVoteCreated(address _nftAddress, address _voterAddress, uint weight, uint appraisal, uint stake);
    //Represents the ending of pricing session and a final appraisal being determined 
    event finalAppraisalDetermined(address _nftAddress, uint appraisal);
    //Log coins being issued to user
    event coinsIssued(uint _amount, address recipient);
    //Log stakes successfully being refunded
    event stakeRefunded(uint _amount, address recipient);
    //Log lossPool successfully being distributed
    event lossPoolDistributed(uint _amount, address recipient);
    
    //onlyOwner equivalent to stop users from calling functions that onyl manager could call 
    modifier onlyManager {
        require(msg.sender == manager, "You are not the manager!");
        _;
    }
    
    //Check if contract is still currently active 
    modifier isActive(address _nftAddress) {
        //If block.timestamp is less than endTime the session is over so user shouldn't be able to vote anymore
        require(block.timestamp < AllPricingSessions[_nftAddress].endTime, "This pricing session is no longer active :(");
        _;
    }
    
    //Enforce session buffer to stop sessions from getting overwritten
    modifier stopOverwrite(address _nftAddress) {
        require(AllPricingSessions[_nftAddress].active = false 
            && now > AllPricingSessions[_nftAddress].endTime + 1 days, "You must wait 1 day before creating new session for this NFT.");
        _;
    }
    
    //Make sure users don't submit more than one appraisal
    modifier oneVoteEach(address _nftAddress) {
        require(!nftVotes[_nftAddress][msg.sender].exists, "Each user only gets one vote!");
        _;
    }
    
    //Check to see that the user has enough money to stake what they promise
    modifier checkStake {
        require(msg.value >= 0.0001 ether, "You must stake some ETH to vote :)");
        _;
    }
    
    //Create a new pricing session
    function createPricingSession(address _nftAddress) stopOverwrite public {
        //Create new instance of PricingSession
        PricingSession memory newSession = PricingSession(block.timestamp, block.timestamp + 1 days, 0, 0, 0, 0, 0, 0, 10000000 ether, true);
        //Assign new instance to NFT address
        AllPricingSessions[_nftAddress] = newSession;
        //Add new NFT address to list of addresses 
        nftAddresses.push(_nftAddress);
        emit sessionCreated(block.timestamp, block.timestamp + 1 days, _nftAddress);
    }
    
    //Sqrt function --> used to calculate sqrt 
    function sqrt(uint x) internal pure returns (uint y) {
        uint z = (x + 1) / 2;
        y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
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
        //Add to total session stake to for reward purposes later on in issueCoin equation
        AllPricingSessions[_nftAddress].totalSessionStake += msg.value;
        //Attach new msg.sender address to newVote (i.e. new Voter struct)
        nftVotes[_nftAddress][msg.sender] = newVote;
        addressesPerNft[_nftAddress].push(msg.sender);
        emit newVoteCreated(_nftAddress, msg.sender, sqrt(msg.value), _appraisal, msg.value);
    }
    
    /* 
    Each vote is weighted based on the lowest stake. So lowest stake starts as 1 vote 
    and the rest of the votes are weighted as a multiple of that. 
    */
    function weightVote(address _nftAddress, address a) onlyManager public {
        //Weighting user at <address a> vote based on lowestStake
        uint weight = sqrt(nftVotes[_nftAddress][a].stake/AllPricingSessions[_nftAddress].lowestStake);
        //Add weighted amount of votes to PricingSession total votes for calculating setFinalAppraisal
        AllPricingSessions[_nftAddress].totalVotes += weight;
        //weight - 1 since one instance was already added in initial setVote function
        totalAppraisalValue[_nftAddress] += (weight-1) * nftVotes[_nftAddress][msg.sender].appraisal;
    }
    
    /*
    Function used to set the final appraisal of a pricing session
    */
    function setFinalAppraisal(address _nftAddress) onlyManager public {
        //Set amountOfVoters for tracking unique voters in a pricing session
        AllPricingSessions[_nftAddress].uniqueVoters = addressesPerNft[_nftAddress].length;
        //Set finalAppraisal by calculating totalAppraisalValue / totalVotes. Scale back the 1000 to make up for scaling method in setVote
        AllPricingSessions[_nftAddress].finalAppraisal = (totalAppraisalValue[_nftAddress])/(AllPricingSessions[_nftAddress].totalVotes);
        nftAddresses.push(_nftAddress);
        AllPricingSessions[_nftAddress].active = false;
        emit finalAppraisalDetermined(_nftAddress, AllPricingSessions[_nftAddress].finalAppraisal);
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

    function calculateBase(address a, address _nftAddress) onlyManager public {
        /*
        Each of the following test the voters guess starting from 105 (5% above) and going down to 95 (5% below). 
        If true nftVotes[_nftAddress][a].base is set to reflect the users base reward
        */
        if (104*AllPricingSessions[_nftAddress].finalAppraisal < 100* nftVotes[_nftAddress][a].appraisal 
            && 105*AllPricingSessions[_nftAddress].finalAppraisal >= 100*nftVotes[_nftAddress][a].appraisal) {
            nftVotes[_nftAddress][a].base = 1;
            inTheMoney.push(a);
        }
        else if (103*AllPricingSessions[_nftAddress].finalAppraisal < 100*nftVotes[_nftAddress][a].appraisal 
            && 104*AllPricingSessions[_nftAddress].finalAppraisal >= 100* nftVotes[_nftAddress][a].appraisal) {
            nftVotes[_nftAddress][a].base = 2;
            inTheMoney.push(a);
        }
        else if (102*AllPricingSessions[_nftAddress].finalAppraisal < 100* nftVotes[_nftAddress][a].appraisal 
            && 103*AllPricingSessions[_nftAddress].finalAppraisal >= 100* nftVotes[_nftAddress][a].appraisal) {
            nftVotes[_nftAddress][a].base = 3;
            inTheMoney.push(a);
        }
        else if (101*AllPricingSessions[_nftAddress].finalAppraisal < 100*nftVotes[_nftAddress][a].appraisal 
            && 102*AllPricingSessions[_nftAddress].finalAppraisal >= 100* nftVotes[_nftAddress][a].appraisal) {
            nftVotes[_nftAddress][a].base = 4;
            inTheMoney.push(a);
        }
        else if (100*AllPricingSessions[_nftAddress].finalAppraisal < 100*nftVotes[_nftAddress][a].appraisal 
            && 101*AllPricingSessions[_nftAddress].finalAppraisal >= 100* nftVotes[_nftAddress][a].appraisal) {
            nftVotes[_nftAddress][a].base = 5;
            inTheMoney.push(a);
        }
        else if (100*AllPricingSessions[_nftAddress].finalAppraisal < 100*nftVotes[_nftAddress][a].appraisal 
            && 99*AllPricingSessions[_nftAddress].finalAppraisal <= 100*nftVotes[_nftAddress][a].appraisal) {
            nftVotes[_nftAddress][a].base = 5;
            inTheMoney.push(a);
        }
        else if (99*AllPricingSessions[_nftAddress].finalAppraisal > 100*nftVotes[_nftAddress][a].appraisal 
            && 98*AllPricingSessions[_nftAddress].finalAppraisal <= 100*nftVotes[_nftAddress][a].appraisal) {
            nftVotes[_nftAddress][a].base = 4;
            inTheMoney.push(a);
        }
        else if (98*AllPricingSessions[_nftAddress].finalAppraisal > 100*nftVotes[_nftAddress][a].appraisal 
            && 97*AllPricingSessions[_nftAddress].finalAppraisal <= 100*nftVotes[_nftAddress][a].appraisal) {
            nftVotes[_nftAddress][a].base = 3;
            inTheMoney.push(a);
        }
        else if (97*AllPricingSessions[_nftAddress].finalAppraisal > 100*nftVotes[_nftAddress][a].appraisal 
            && 96*AllPricingSessions[_nftAddress].finalAppraisal <= 100*nftVotes[_nftAddress][a].appraisal) {
            nftVotes[_nftAddress][a].base = 2;
            inTheMoney.push(a);
        }
        else if (96*AllPricingSessions[_nftAddress].finalAppraisal > 100*nftVotes[_nftAddress][a].appraisal 
            && 95*AllPricingSessions[_nftAddress].finalAppraisal <= 100*nftVotes[_nftAddress][a].appraisal) {
            nftVotes[_nftAddress][a].base = 1;
            inTheMoney.push(a);
        }
        //In this case the user is out of the money
        else {
            nftVotes[_nftAddress][a].base = 0;
            outTheMoney.push(a);
        }
    }
    
    /*
    At conclusion of pricing session we harvest the losses of users
    that made guesses outside of the 5% over/under the finalAppraisalPrice
    
    Should return amount total loss harvest amount 
    */
   function harvestLoss(address a, address _nftAddress) public onlyManager returns(uint){
       /*
       Checks users that are out of the money for how far over (in first if statement) 
       or under (in else if) they are and adjusts their stake balance accordingly
       */
        if (nftVotes[_nftAddress][a].appraisal*100 > 105*AllPricingSessions[_nftAddress].finalAppraisal){
            AllPricingSessions[_nftAddress].lossPoolTotal += nftVotes[_nftAddress][a].stake * (nftVotes[_nftAddress][a].appraisal*100 - 105*AllPricingSessions[_nftAddress].finalAppraisal)
                /(AllPricingSessions[_nftAddress].finalAppraisal*100);
            nftVotes[_nftAddress][a].stake = 
                (nftVotes[_nftAddress][a].stake - nftVotes[_nftAddress][a].stake * (nftVotes[_nftAddress][a].appraisal*100 - 105*AllPricingSessions[_nftAddress].finalAppraisal)
                /(AllPricingSessions[_nftAddress].finalAppraisal*100));
            return nftVotes[_nftAddress][a].stake;
        }
        else if(nftVotes[_nftAddress][a].appraisal*100 < 95*AllPricingSessions[_nftAddress].finalAppraisal){
            AllPricingSessions[_nftAddress].lossPoolTotal += nftVotes[_nftAddress][a].stake * (95*AllPricingSessions[_nftAddress].finalAppraisal - 100*nftVotes[_nftAddress][a].appraisal)
                /(AllPricingSessions[_nftAddress].finalAppraisal*100);
            nftVotes[_nftAddress][a].stake = 
                (nftVotes[_nftAddress][a].stake - nftVotes[_nftAddress][a].stake * (95*AllPricingSessions[_nftAddress].finalAppraisal - 100*nftVotes[_nftAddress][a].appraisal)
                /(AllPricingSessions[_nftAddress].finalAppraisal*100));
            return nftVotes[_nftAddress][a].stake;
        }
        else {
            return nftVotes[_nftAddress][a].stake;
        }
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
    function issueCoins(address a, address _nftAddress) internal onlyManager returns(bool){
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
        emit coinsIssued(amount, a);
        //returns true if function ran smoothly and correctly executed
        return true;
    }
    
    //Refund each users stake
    function refundStake(address payable a, address _nftAddress) public onlyManager returns(bool) {
        require(nftVotes[_nftAddress][a].stake > 0);
        //sends stakes back to users
        a.transfer(nftVotes[_nftAddress][a].stake);
        //sets stake to 0 to avoid re-entrancy
        nftVotes[_nftAddress][a].stake = 0;
        emit stakeRefunded(nftVotes[_nftAddress][a].stake, a);
        //function returns true if stake was sent back correctly. 
        return true;
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
    function distributeLossPool(address payable receiver, address _contract) public onlyManager returns(bool){
        //Receiver is any owner of a $PP. Splits up contract balance and multiplies share per coin by user balancOf coins
        receiver.transfer(balanceOf(receiver) * _contract.balance/totalSupply());
        emit lossPoolDistributed(balanceOf(receiver) * _contract.balance/totalSupply(), receiver);
        return true;
    }
    
    function getTotalSessionStake(address _nftAddress) view public returns(uint) {
        return AllPricingSessions[_nftAddress].totalSessionStake;
    }
    
    function getEndTime(address _nftAddress) view public returns(uint) {
        return AllPricingSessions[_nftAddress].endTime;
    }
    
    function getTimeLeft(address _nftAddress) view public returns(uint) {
        uint timeLeft;
        if(AllPricingSessions[_nftAddress].endTime < block.timestamp) {
            timeLeft = AllPricingSessions[_nftAddress].endTime - block.timestamp;
        }
        else {
            timeLeft = 0;
        }
        return timeLeft;
    }
    
    function getTotalVoters(address _nftAddress) view public returns(uint) {
        return addressesPerNft[_nftAddress].length;
    }
    
    function getTreasury(address a) view public returns(uint) {
        return a.balance;
    }
    
    function getVote(address a, address _nftAddress) view public onlyManager returns(uint) {
        return nftVotes[_nftAddress][a].appraisal;
    }
    
    function getStake(address _nftAddress) view public onlyManager returns(uint) {
        return nftVotes[_nftAddress][msg.sender].stake;
    }
    
    function getFinalAppraisal(address _nftAddress) view public returns(uint) {
        return AllPricingSessions[_nftAddress].finalAppraisal;
    }   
}


