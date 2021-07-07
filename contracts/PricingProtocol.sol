// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract PricingProtocol is ERC20, Ownable{
    
    mapping(address => uint) public stake;
    mapping(address => uint) private appraisalPrice;
    uint public finalAppraisal; 
    
    enum ContractActiveStatus{ ACTIVE, INACTIVE }
    ContractActiveStatus contractStatus;

    // Struct of the voter
    struct Voter{
        //Index of the voted Proposal
        uint vote;
        //Weight ???
        uint weight;
        //True if user already voted
        bool voted;
    }

    struct Bid{
        string blindBid;
        uint deposit;
    }

    struct Proposal{
        //It should contain the 
        //info of NFT, with its
        //pricing etc.
    }
    
    constructor() ERC20("PricingCoin", "PP") {

    }
    
    //Check if contract is active
    modifier checkActive {
        require(contractStatus == ContractActiveStatus.ACTIVE);
        _;
        
    }
    
    
    modifier checkStake {
        require(stake[msg.sender] > 0);
        _;
    }
    
    //Allow users to submit votes, given that they have some eth staked
    function newVote(uint _deposit) checkStake public returns(bool){
        
    }
    
    /*
    At conclusion of pricing session we issue coins to users within ___ of price:
        - 1% --> 5 $PP
        - 2% --> 4 $PP
        - 3% --> 3 $PP
        - 4% --> 2 $PP
        - 5% --> 1 $PP
    */
    function issueCoins() internal returns(bool){
        
    }

    /*
    At conclusion of pricing session we harvest the losses of users
    that made guesses outside of the 5% over/under the finalAppraisalPrice
    */
    function harvestLoss() internal returns(bool){
        
    }
    
    /*
    Loss pool should be divided by the amount of tokens in circulation and
    distributed to each coin holder wallet. For example if loss pool held 10 
    eth and there were 10 coins in circulation each coin would recieve 0.1 eth.
    */
    function distributeLossPool() internal returns(bool){
        
    }
    
}