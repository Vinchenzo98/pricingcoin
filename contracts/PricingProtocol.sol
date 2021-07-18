// SPDX-License-Identifier: GPL-3.0

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

pragma solidity >=0.4.22 <0.9.0;

contract PricingProtocol is ERC20{
    address public manager;
    //Maps the total appraisal value to an NFT address
    mapping(address => uint) totalAppraisalValue;
    
    //Initial constructor for the entire Pricing Protocol contract
    constructor(uint256 initialSupply) ERC20("PricingCoin", "PP") {
        _mint(msg.sender, initialSupply);
        manager = msg.sender;
    }
    
    //Voter struct to allow users to submit votes, stake, and track that the user has already voted (i.e. exists = true) 
    struct Voter {
        uint base;
        uint weight;
        uint appraisal;
        uint stake;
        bool exists;
    }
    
    //Mapping used to track how many voters have voted on a particular NFT
    mapping(address => address[]) addressesPerNft;
    
    //Keeps track of important data from each pricing session in the form of an item
    struct PricingSession {
        uint startTime;
        uint endTime;
        uint finalAppraisal;
        uint amountOfVoters;
        uint totalVotes;
        uint tokensIssued;
        uint lossPoolTotal;
        uint totalSessionStake;
    }
    
    //Find a pricing session and all its information (PricingSession struct) by the NFT address
    mapping(address => PricingSession) AllPricingSessions;
    //Track how many NFTs have been priced
    address[] nftAddresses;
    //Track votes at a given nft address
    mapping(address => mapping (address => Voter)) nftVotes;
    
    event newVoteCreated(address _nftAddress, address _voterAddress, uint weight, uint appraisal, uint stake);
    
    event finalAppraisalDetermined(address _nftAddress, uint appraisal);
    
    //onlyOwner equivalent to stop users from calling functions that onyl manager could call 
    modifier onlyManager {
        require(msg.sender == manager, "You are not the manager!");
        _;
    }
    
    //Check if contract is active
    modifier isActive(address _nftAddress) {
        require(block.timestamp < AllPricingSessions[_nftAddress].endTime, "This pricing session is no longer active :(");
        _;
    }
    
    //Make sure users don't submit more than one appraisal
    modifier oneVoteEach(address _nftAddress) {
        require(!nftVotes[_nftAddress][msg.sender].exists, "Each user only gets one vote!");
        _;
    }
    
    //Check to see that the user has enough money to stake what they promise
    modifier checkStake {
        require(msg.value > 0, "You must stake some ETH to vote :)");
        _;
    }
    
    //Create a new pricing session
    function createPricingSession(address _contractAddress) onlyManager public {
        PricingSession memory newSession = PricingSession(block.timestamp, block.timestamp + 1 days, 0, 0, 0, 0, 0, 0);
        AllPricingSessions[_contractAddress] = newSession;
        nftAddresses.push(_contractAddress);
    }
    
    /* 
    This function allows users to create a new vote for an NFT. 
    
    Each vote will be weighted using a simple quadratic voting formula --> sqrt(stake/0.1 ETH)
    */
    function setVote(uint _appraisal, address _nftAddress) checkStake isActive(_nftAddress) oneVoteEach(_nftAddress) payable public {
        require(msg.value >= 0.0001 ether, "You must stake more than 0.0001 ETH to vote!");
        Voter memory newVote = Voter(0, sqrt(msg.value/10**12), _appraisal, msg.value, true);
        totalAppraisalValue[_nftAddress] += _appraisal*sqrt(msg.value/10**12);
        AllPricingSessions[_nftAddress].totalVotes += sqrt(msg.value/10**12);
        AllPricingSessions[_nftAddress].totalSessionStake += msg.value;
        nftVotes[_nftAddress][msg.sender] = newVote;
        addressesPerNft[_nftAddress].push(msg.sender);
        emit newVoteCreated(_nftAddress, msg.sender, sqrt(msg.value), _appraisal, msg.value);
    }
    
    function getTreasury(address a) view public returns(uint) {
        return a.balance;
    }
    
    function getVote(address a, address _nftAddress) view public onlyManager returns(uint) {
        return nftVotes[_nftAddress][a].appraisal;
    }
    
    function getStake(address _nftAddress) view public returns(uint) {
        return nftVotes[_nftAddress][msg.sender].stake;
    }
    
    // the divided by 100 references the sqrt 10**12 which is 10**18/10**6 => sqrt 10**6 = 1000; 
    function setFinalAppraisal(address _nftAddress) public onlyManager {
        AllPricingSessions[_nftAddress].amountOfVoters = addressesPerNft[_nftAddress].length;
        //Fix this for weighting system
        AllPricingSessions[_nftAddress].finalAppraisal = (totalAppraisalValue[_nftAddress]/1000)/(AllPricingSessions[_nftAddress].totalVotes/1000);
        nftAddresses.push(_nftAddress);
        emit finalAppraisalDetermined(_nftAddress, AllPricingSessions[_nftAddress].finalAppraisal);
    }
    
    function getFinalAppraisal(address _nftAddress) view public returns(uint) {
        return AllPricingSessions[_nftAddress].finalAppraisal;
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
    function sqrt(uint x) internal pure returns (uint y) {
        uint z = (x + 1) / 2;
        y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
    }
    
    function calculateBase(address a, address _nftAddress) public {
        if (104*AllPricingSessions[_nftAddress].finalAppraisal < 100* nftVotes[_nftAddress][a].appraisal 
            && 105*AllPricingSessions[_nftAddress].finalAppraisal >= 100*nftVotes[_nftAddress][a].appraisal) {
            nftVotes[_nftAddress][a].base = 1;
        }
        else if (103*AllPricingSessions[_nftAddress].finalAppraisal < 100*nftVotes[_nftAddress][a].appraisal 
            && 104*AllPricingSessions[_nftAddress].finalAppraisal >= 100* nftVotes[_nftAddress][a].appraisal) {
            nftVotes[_nftAddress][a].base = 2;
        }
        else if (102*AllPricingSessions[_nftAddress].finalAppraisal < 100* nftVotes[_nftAddress][a].appraisal 
            && 103*AllPricingSessions[_nftAddress].finalAppraisal >= 100* nftVotes[_nftAddress][a].appraisal) {
            nftVotes[_nftAddress][a].base = 3;
        }
        else if (101*AllPricingSessions[_nftAddress].finalAppraisal < 100*nftVotes[_nftAddress][a].appraisal 
            && 102*AllPricingSessions[_nftAddress].finalAppraisal >= 100* nftVotes[_nftAddress][a].appraisal) {
            nftVotes[_nftAddress][a].base = 4;
        }
        else if (100*AllPricingSessions[_nftAddress].finalAppraisal < 100*nftVotes[_nftAddress][a].appraisal 
            && 101*AllPricingSessions[_nftAddress].finalAppraisal >= 100* nftVotes[_nftAddress][a].appraisal) {
            nftVotes[_nftAddress][a].base = 5;
        }
        else if (100*AllPricingSessions[_nftAddress].finalAppraisal < 100*nftVotes[_nftAddress][a].appraisal 
            && 99*AllPricingSessions[_nftAddress].finalAppraisal <= 100*nftVotes[_nftAddress][a].appraisal) {
            nftVotes[_nftAddress][a].base = 5;
        }
        else if (99*AllPricingSessions[_nftAddress].finalAppraisal > 100*nftVotes[_nftAddress][a].appraisal 
            && 98*AllPricingSessions[_nftAddress].finalAppraisal <= 100*nftVotes[_nftAddress][a].appraisal) {
            nftVotes[_nftAddress][a].base = 4;
        }
        else if (98*AllPricingSessions[_nftAddress].finalAppraisal > 100*nftVotes[_nftAddress][a].appraisal 
            && 97*AllPricingSessions[_nftAddress].finalAppraisal <= 100*nftVotes[_nftAddress][a].appraisal) {
            nftVotes[_nftAddress][a].base = 3;
        }
        else if (97*AllPricingSessions[_nftAddress].finalAppraisal > 100*nftVotes[_nftAddress][a].appraisal 
            && 96*AllPricingSessions[_nftAddress].finalAppraisal <= 100*nftVotes[_nftAddress][a].appraisal) {
            nftVotes[_nftAddress][a].base = 2;
        }
        else if (96*AllPricingSessions[_nftAddress].finalAppraisal > 100*nftVotes[_nftAddress][a].appraisal 
            && 95*AllPricingSessions[_nftAddress].finalAppraisal <= 100*nftVotes[_nftAddress][a].appraisal) {
            nftVotes[_nftAddress][a].base = 1;
        }
        else {
            nftVotes[_nftAddress][a].base = 0;
        }
    }
    
    function issueCoins(address a, address _nftAddress) internal onlyManager returns(bool){
        uint amount; 
        if (addressesPerNft[_nftAddress].length < 10) {
            amount = 0;
        }
        else if (addressesPerNft[_nftAddress].length >= 10) {
            amount = (nftVotes[_nftAddress][a].base * sqrt(nftVotes[_nftAddress][a].stake) * sqrt(addressesPerNft[_nftAddress].length) * 
                sqrt(AllPricingSessions[_nftAddress].totalSessionStake)/sqrt(10**18))/sqrt(10**18);
        }
        _mint(a, amount);
        AllPricingSessions[_nftAddress].tokensIssued += amount;
        return true;
    }

    /*
    At conclusion of pricing session we harvest the losses of users
    that made guesses outside of the 5% over/under the finalAppraisalPrice
    
    Should return amount total loss harvest amount 
    */
   function harvestLoss(address a, address _nftAddress) public onlyManager returns(uint){
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
    
    //Refund each users stake
    function refundStake(address payable a, address _nftAddress) public onlyManager returns(bool) {
        require(nftVotes[_nftAddress][a].stake > 0);
        a.transfer(nftVotes[_nftAddress][a].stake);
        nftVotes[_nftAddress][a].stake = 0;
        return true;
    }
    
}
