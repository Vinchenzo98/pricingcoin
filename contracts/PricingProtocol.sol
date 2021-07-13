// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.4.22 <0.9.0;

contract PricingCoin {
    address manager;
    uint startTime;
    uint endTime;
    
    constructor() public {
        manager = msg.sender;
        startTime = now;
        endTime = now + 1 days; 
    }
    
    mapping(address => uint) private finalAppraisalPrice;
    
    struct Voter {
        uint appraisal;
        uint stake;
        bool exists;
    }
    
    mapping (address => Voter) voters;
    address[] public addresses;
    
    //Check if contract is active
    modifier isActive {
        require(now < endTime);
        _;
    }
    
    //Make sure users don't submit more than one appraisal
    modifier oneVoteEach {
        require(!voters[msg.sender].exists);
        _;
    }
    
    //Check to see that the user has enough money to stake what they promise
    modifier checkStake {
        require(msg.value > 0);
        _;
    }
    
    //Allow users to create new vote.
    function setVote(uint _appraisal) checkStake isActive oneVoteEach payable public {
        Voter memory newVote = Voter(_appraisal, msg.value, true);
        voters[msg.sender] = newVote;
        addresses.push(msg.sender);
    }
    
    function getTreasury(address a) view public returns(uint) {
        return a.balance;
    }
    
    function getVote() view public returns(uint) {
        return voters[msg.sender].appraisal;
    }
    
    function getStake() view public returns(uint) {
        return voters[msg.sender].stake;
    }
    
    /*
    At conclusion of pricing session we issue coins to users within ___ of price:
        - 1% --> 5 $PP
        - 2% --> 4 $PP
        - 3% --> 3 $PP
        - 4% --> 2 $PP
        - 5% --> 1 $PP
        
    Should return true if the coins were issued correctly
    */
    function issueCoins() internal returns(bool){
        
    }

    /*
    At conclusion of pricing session we harvest the losses of users
    that made guesses outside of the 5% over/under the finalAppraisalPrice
    
    Should return amount total loss harvest amount 
    */
    function harvestLoss() internal returns(uint){
        
    }
    
    /*
    Loss pool should be divided by the amount of tokens in circulation and
    distributed to each coin holder wallet. For example if loss pool held 10 
    eth and there were 10 coins in circulation each coin would recieve 0.1 eth.
    
    Should return true if loss pool is completely distributed
    */
    function distributeLossPool() internal returns(bool){
        
    }
    
    //Refund each users stake
    function refundStake() internal returns(bool) {
        
    }
    
}
