# 🥪 aave-credit-dele 🥪

A "delicatessen" for native credit delegation on Aave v2.

## 📄 Description

Here is a long description of the app.

## 🎞 Demo

Screenshots:

Gifs:

Site:

### Initial idea

Aave has this great feature called Credit Delegation. Credit Delegation are currently part of Aave v2 Smart contracts and enable depositors to delegate their borrowing power (also called credit line) to other borrowers.

One example, let's say Bob deposits 1m USD in ether in Aave to earn the current ETH yield. This 1m deposit acts as a collateral on Aave. Now, let's say Bob doesn't want to borrow against his ETH deposit and if we imagine a collateral ratio of 50%, this mean that Bob potentially has a 500k unused borrowing power.

Now comes Alice who has little crypto assets and would like to have a greater borrowing capacity (this is a very relevant topic to today's crazy yield farms times and democratizing wealth accesses to smaller portfolios). Alice and Bob could "meet" offchain or onchain and Bob could delegate his credit line to Alice. This is pretty powerful because that means Alice doesn't need to have large holdings to benefit from a great borrowing power.

The purpose of the project would be to build a DApp that would enable Alice and Bob to meet and consent on an agreement on the 500k loan. Features of the loan would be duration, extra yield for Bob of course...

Now there are a few problems because I would like the agreement to be entirely settled on chain if possible. The problem here would be trust. How can we make sure that Alice doesn't run away with the 500k loan she benefited from Bob credit line if she doesn't put any collateral? For that we could think of incentives (rating borrowers for e.g.) or maybe try to incorporate a 3rd party that would insure Bob in case Alice defaults and runs away with the money. The incentives largely remain to be determined.

#### Additional details on managing trust of the borrower

To solve the trust problem, I have also started thinking about ideas. Essentially, the loan never has to go to Alice wallet directly. So the idea would be that Bob delegated his credit line to a pool and Alice would interact with the pool directly and choose a yield strategy connected to the pool. She only posts a small amount of collateral in case her borrowing value goes down (IL or whatever reason). Bob earns extra yield by agreeing with Alice on whatever profit he should share from whatever yield strategy Alice chose.

## 👥 Contributors

[@platocrat](https://github.com/platocrat/)
