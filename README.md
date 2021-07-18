# pricingcoin
Idea:
The goal of this pricing protocol is have the community help users price items of unknown value (i.e. a new NFT).

How it works:
Step 1: A user uploads an NFT for appraisal purposes.
Step 2: Community members vote to price the NFT based on what they think it is worth.
- In order to vote a user must stake any amount of ETH or $PP (Pricing Protocol coin). Each vote will be weighted by the amount the user stakes relative to the entire pricing pool. Furthermore, to minimize a users ability to disproportionately influence the pricing of an item we will use a quadratic staking method to weight a users vote.

Step 3: Community voting concludes, appraised price is determined.
Step 4: Post-pricing rewards.
- A “winner” is any user that chose a price within 5% of the final appraised price. $PP will be distributed to winners based on those that are within 5% in different tranches: Within 1% receives 5 $PP, 2% receives 4 $PP, 3% receives 3 $PP, 4% receives 2 $PP, 5% receives 1 $PP.

- A “loser” is any user that chose a price outside of 5% of the final appraised price. The losers of a pricing session lose a percentage of their stake based on how far outside of the 5% mark they chose. For example, if a user guesses 6% off of the average price they lose 1% of their stake. This money is pooled (call it a “loss pool”) and distributed to all $PP token holders.

Token Utility:
As explained above, holding a token makes you eligible to receive a piece of the loss pool from each pricing session.
