// SPDX-License-Identifier: GPL-3.0

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

pragma solidity >=0.4.22 <0.9.0;

contract PricingProtocol is ERC20{
    address manager;
    uint startTime;
    uint endTime;
    uint totalAppraisalValue;
    uint finalAppraisalPrice;
    
    constructor(uint256 initialSupply) ERC20("PricingCoin", "PP") {
        _mint(msg.sender, initialSupply);
        manager = msg.sender;
        startTime = block.timestamp;
        endTime = block.timestamp + 1 days;
    }
    
    // mapping(address => uint) private finalAppraisalPrice;
    
    struct Voter {
        uint appraisal;
        uint stake;
        bool exists;
    }
    
    mapping (address => Voter) voters;
    address[] addresses;
    
    modifier onlyManager {
        require(msg.sender == manager);
        _;
    }
    
    //Check if contract is active
    modifier isActive {
        require(block.timestamp < endTime);
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
        totalAppraisalValue += _appraisal; 
        voters[msg.sender] = newVote;
        addresses.push(msg.sender);
    }
    
    function getTreasury(address a) view public returns(uint) {
        return a.balance;
    }
    
    function getVote(address a) view public onlyManager returns(uint) {
        return voters[a].appraisal;
    }
    
    function setStake(address a, uint _num) public returns(bool) {
        voters[a].stake = _num;
        return true; 
    }
    
    function getStake() view public returns(uint) {
        return voters[msg.sender].stake;
    }
    
    function setFinalAppraisal() public onlyManager returns(uint) {
        finalAppraisalPrice = totalAppraisalValue/addresses.length;
        return finalAppraisalPrice;
    }
    
    function getFinalAppraisal() view public returns(uint) {
        return finalAppraisalPrice;
    }
    
    /*
    At conclusion of pricing session we issue coins to users within ___ of price:
        - 1% --> 10 $PP
        - 2% --> 5 $PP
        - 3% --> 3 $PP
        - 4% --> 2 $PP
        - 5% --> 1 $PP
        
    Should return true if the coins were issued correctly
    */
    function issueCoins(address account, uint amount) internal onlyManager returns(bool){
        _mint(account, amount);
        return true;
    }

    /*
    At conclusion of pricing session we harvest the losses of users
    that made guesses outside of the 5% over/under the finalAppraisalPrice
    
    Should return amount total loss harvest amount 
    */
   function harvestLoss(address a) public onlyManager returns(uint){
        if (voters[a].appraisal*100 > 105*finalAppraisalPrice){
            voters[a].stake = 
                (voters[a].stake - voters[a].stake * (voters[a].appraisal*100 - 105*finalAppraisalPrice)
                /(finalAppraisalPrice*100));
            return voters[a].stake;
        }
        else if(voters[a].appraisal*100 < 95*finalAppraisalPrice){
            voters[a].stake = 
                (voters[a].stake - voters[a].stake * (95*finalAppraisalPrice - 100*voters[a].appraisal)
                /(finalAppraisalPrice*100));
            return voters[a].stake;
        }
        else {
            return voters[a].stake;
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
    function distributeLossPool(address payable receiver, address _contract) public onlyManager returns(bool){
        receiver.transfer(balanceOf(receiver) * _contract.balance/totalSupply());
        return true;
    }
    
    function getValuePerToken( address _contract) view public returns(uint){
        return _contract.balance/totalSupply();
    }
    
    //Refund each users stake
    function refundStake(address payable a) public onlyManager returns(bool) {
        require(voters[a].stake > 0);
        a.transfer(voters[a].stake);
        voters[a].stake = 0;
        return true;
    }
    
}
