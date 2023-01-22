Core project for Motoko bootcamp of 2023.

Interface/svelte provided by bootcamp.
Motoko/backend written by author.

Features :  
functional -
	submit_proposal
	get_proposal
	get_all_proposals
	vote
	modify_parameters

barely functional -
	(createNeuron) - user needs to send the tokens beforehand to account(canister's principal, blob derived from caller's principal)
	(dissolveNeuron)

To deploy a copy of the Dao :
1. Create 3 canisters to deploy in
2. Modify canister_ids.json to fit your canisters.
3. Change the 
	"daoCanisterId" in Connexion.js, 
	"webpage" actorPrincipal in src/dao/main.mo
	"mbtCanister" actorPrincipal in src/dao/main.mo
	"allowList" in src/webpage/main.mo
4. Run dfx generate and npm install
5. deploy to mainnet

Checks the current voting power of every user when a new vote is cast or when checkVotingResult is called. To prevent voting multiple times with same tokens, and to account for changing neuron voting power.
Voting power is equal to tokens held and user's neuron.
Neurons lock all tokens at the subaccount's address at function call. 
Proposal result checks first for the "passed". Passed proposals stay alive forever and cant be modified, proposals voted to be removed are removed 'forever'.
Function "vote" returns on successful voting needs tuning. 
Gets decimals automatically from token canister for internal use.
Used Tries for databases. All memory is stable.
