import Trie "mo:base/Trie";
import Hash "mo:base/Hash";
import Text "mo:base/Text";
import Nat "mo:base/Nat";
import Time "mo:base/Time";
import Principal "mo:base/Principal";
import Float "mo:base/Float";
import Int "mo:base/Int";
import Result "mo:base/Result";
import Iter "mo:base/Iter";
import Buffer "mo:base/Buffer";
import Array "mo:base/Array";
import Option "mo:base/Option";
import List "mo:base/List";
import Nat8 "mo:base/Nat8";
import Prim "mo:⛔"

actor{
    let webpage : actor { updateProposal : (Text) -> async Text } = actor ("d6t3t-tqaaa-aaaal-qbshq-cai"); 

    let canisterPrincipal = Principal.fromText("dzs5h-6iaaa-aaaal-qbsha-cai");
    let mbtCanister : actor {
        icrc1_decimals : () -> async (Nat8);
        icrc1_balance_of : (Account) -> async (Nat) ;  
        icrc1_transfer : (TransferArgs) -> async ({ Ok: Nat; Err: TransferError; });
        } = actor ("db3eq-6iaaa-aaaah-abz6a-cai");
        
    stable var neurons : Trie.Trie<Principal, Neuron> = Trie.empty();
    stable var proposals : Trie.Trie<Int, Proposal> = Trie.empty();
    
    func key(t: Principal) : Trie.Key<Principal> { { hash = Principal.hash t; key = t } };
    func keyInt(t : Int) : Trie.Key<Int> { { hash = Int.hash t; key = t} };
    
    stable var nextProposalId : Nat = 1;
    stable var minimumHold : Nat = 1;
    stable var quadraticVoting : Bool = false;
    stable var passLimit : Float = 100;
    let secondsInMonth : Nat = 60*60*24*30;
    let secondsInDay : Nat = 60*60*24;

    public func checkVotingResult(proposalId : Int) : async Text{
        let proposal = Trie.get(proposals, keyInt(proposalId), Int.equal);
        var noVotesTotal : Float = 0;
        var yesVotesTotal : Float = 0;
        switch(proposal){
            case(null){return "no such proposal"};
            case(?some){
                
                for(user in List.toIter<Principal>(some.votedFor)){
                    noVotesTotal += await votingPower(user, some.quadratic);
                };
                for(user in List.toIter<Principal>(some.votedAgainst)){
                    yesVotesTotal += await votingPower(user, some.quadratic);
                };
                if(yesVotesTotal >= passLimit){
                    let new : Proposal = {
                        info = some.info;
                        id = some.id;
                        quadratic = some.quadratic;
                        passLimit = some.passLimit;
                        minimumVote = some.minimumVote;
                        passed = true;
                        votedFor = some.votedFor;
                        votedAgainst = some.votedAgainst;
                    };
                    ignore webpage.updateProposal(some.info);
                    return "proposal passed";
                };
                if(noVotesTotal >= passLimit){
                    ignore Trie.remove(proposals, keyInt(proposalId), Int.equal);
                    return "proposal removed";
                };

                return ("Yes votes" # Float.toText(yesVotesTotal) # " - No votes " # Float.toText(noVotesTotal));
            };
        };
    };
    
    func votingPower(user : Principal, quadratic : Bool) : async Float{        
        let userAccount = {owner = user; subaccount = null};
        let tokenDecimalFix : Float = Float.fromInt(Nat.pow(10, Nat8.toNat(await mbtCanister.icrc1_decimals())));
        var votingPower : Float = (Float.fromInt(await mbtCanister.icrc1_balance_of(userAccount)) / tokenDecimalFix);
        var neuronVotingPower : Float = 0;
        var totalPower : Float = 0;
        switch(Trie.get(neurons, key(user), Principal.equal)){
            case(null){};
            case(?x){neuronVotingPower := neuronVotingPowerCalculator(x)};
        };
        totalPower := votingPower + neuronVotingPower;
        if(quadratic){totalPower := Float.sqrt(totalPower)};
        return totalPower;
    };

    func neuronVotingPowerCalculator(neuron : Neuron) : Float{
        //update dissolveDelay before voting power
        var neuronUpdated : Neuron = neuron;
        switch(neuron.dissolving){
            case(true){neuronUpdated := updateDissolveDelay(neuronUpdated)};
            case(false){};
        };
        let elapsedSeconds = (Time.now()-neuronUpdated.creationTime)/1000_000_000;
        let timeMultiplier = 1 + (Float.min((Float.fromInt(elapsedSeconds/secondsInDay) / 365), 4) * (0.25/4));

        let dissolveDays = Float.fromInt(neuronUpdated.dissolveDelay/1000_000_000/secondsInDay);
        if(dissolveDays < 180){ return Float.fromInt(neuronUpdated.tokenAmount)}
        else if(dissolveDays > (8*365)) {return Float.fromInt(neuronUpdated.tokenAmount * 8)}
        else { return (1.06 + ((8-1.06) * (dissolveDays/(8*365-180))))};
    };
    

    func updateDissolveDelay(neuron : Neuron) : Neuron{
        var dissolveDelay = neuron.dissolveDelay;
        let timeNow = Time.now();
        let timeSinceLastUpdate = timeNow - neuron.dissolvingLastTimeStamp;

        if(Int.lessOrEqual(dissolveDelay, timeSinceLastUpdate)){
            //If neuron dissolving is over, or dissolved
            let newNeuron : Neuron = {
                dissolveDelay = 0;
                subAccountBlob = neuron.subAccountBlob;
                creationTime = neuron.creationTime;
                tokenAmount = neuron.tokenAmount;
                dissolving  = false;
                dissolvingLastTimeStamp = timeNow;
            };
            return newNeuron;
        };

        dissolveDelay := dissolveDelay - timeSinceLastUpdate;
        let newNeuron : Neuron = {
            //Updates the dissolvedelay from last timestamp
            dissolveDelay = dissolveDelay;
            creationTime = neuron.creationTime;
            subAccountBlob = neuron.subAccountBlob;
            tokenAmount = neuron.tokenAmount;
            dissolving = true;
            dissolvingLastTimeStamp = timeNow;
        };
        return newNeuron;
    };

    
    public shared (msg) func submit_proposal(proposalInfo : Text): async {#Ok : Proposal; #Err : Text}{
        let userAccount = {owner = msg.caller; subaccount = null};
        let tokenDecimalFix : Float = Float.fromInt(Nat.pow(10, Nat8.toNat(await mbtCanister.icrc1_decimals())));
        let userTokens : Float = Float.fromInt(await mbtCanister.icrc1_balance_of(userAccount)) / tokenDecimalFix;
        if(userTokens >= 1){
            let nextId = nextProposalId;
            nextProposalId += 1;
            let newProposal : Proposal = {
                info = proposalInfo;
                id = nextId;
                passed = false;
                quadratic = false;
                passLimit = 100;
                votedFor = List.nil<Principal>();
                minimumVote = 1;
                votedAgainst = List.nil<Principal>();};
                
            proposals := Trie.put(proposals, keyInt(nextId), Int.equal, newProposal).0;
            return #Ok(newProposal);
        }; return #Err("not enough tokens");
    };
    public query func get_proposal(proposalId : Int) : async ?Proposal{
        Trie.get(proposals, keyInt(proposalId), Int.equal);
    };
    public query func get_all_proposals() : async [(Int, Proposal)]{
        let proposalsArray = Iter.toArray(Trie.iter(proposals));
    };  

    public shared (msg) func vote(proposalId : Int, yesOrNo : Bool) : async {#Ok : (Nat, Nat); #Err : Text}{
        let proposal = Trie.get(proposals, keyInt(proposalId), Int.equal);
        let f = func(p : Principal) : Bool {Principal.equal(p, msg.caller)};
        switch(proposal){
            case(null){return #Err("No such proposal");};
            case(?some){
                if(some.passed){return #Err("already passed")};
                let votePower = await votingPower(msg.caller, some.quadratic);
                if(some.minimumVote > votePower){return #Err("not enough tokens")};
                switch(yesOrNo){
                    case(true){
                    if(List.find<Principal>(some.votedFor, f) != null){return #Err("already voted")}
                    else {
                    let fixedProposal : Proposal = {info = some.info;
                    id = some.id;
                    quadratic = some.quadratic;
                    passed = false;
                    passLimit = some.passLimit;
                    votedFor = List.push<Principal>(msg.caller, some.votedFor);
                    minimumVote = some.minimumVote;
                    votedAgainst = some.votedAgainst;};
                   
                    proposals := Trie.put(proposals, keyInt(proposalId), Int.equal, fixedProposal).0;
                    ignore await checkVotingResult(proposalId);
                    return #Ok((1, 1));
                    };
                };
                    case(false){
                        if(List.find<Principal>(some.votedAgainst, f) != null){return #Err("already voted")}
                        else {
                        let fixedProposal : Proposal = {info = some.info;
                        quadratic = some.quadratic;
                        passLimit = some.passLimit;
                        id = some.id;
                        minimumVote = some.minimumVote;
                        passed = false;
                        votedAgainst = List.push<Principal>(msg.caller, some.votedAgainst);
                        votedFor = some.votedFor;};
                        proposals := Trie.put(proposals, keyInt(proposalId), Int.equal, fixedProposal).0;
                        ignore await checkVotingResult(proposalId);
                        return #Ok((1,1));
                        };
                    };
                };
        };
        };
    };
    public shared (msg) func modify_parameters(proposalId : Nat, passLimit : ?Float, quad : ?Bool, info : ?Text) : async Text{
        let propTo = Trie.get(proposals, keyInt(proposalId), Int.equal);
        switch(propTo){
            case(null){return "No such proposal"};
            case(?prop){
                if(prop.passed){return "Already passed proposal"}
                else{
                    let newProposal : Proposal = {
                        id = proposalId;
                        passLimit = Option.get(passLimit, prop.passLimit);
                        quadratic = Option.get(quad, prop.quadratic);
                        info = Option.get(info, prop.info);
                        votedAgainst = prop.votedAgainst;
                        minimumVote = prop.minimumVote;
                        votedFor = prop.votedFor;
                        passed = prop.passed;
                    };
                    proposals := Trie.put(proposals, keyInt(proposalId), Int.equal, newProposal).0;
                    return "Proposal modified";
                };
            };
        };
    };

    
    public shared(msg) func createNeuron(delay : Int) : async Text{
        let oldNeuron = Trie.get(neurons, key(msg.caller), Principal.equal);
        let tokenBalance =await mbtCanister.icrc1_balance_of({owner = canisterPrincipal; subaccount = ?Principal.toBlob(msg.caller)}); 
         if(tokenBalance == 0){return "You need to send tokens first"};
        switch(oldNeuron){
            case(null){
                let newNeuron : Neuron = {dissolveDelay = delay;
                    creationTime = Time.now();
                    tokenAmount = tokenBalance;
                    dissolving = false;
                    subAccountBlob = Principal.toBlob(msg.caller);
                    dissolvingLastTimeStamp = 0;};
                    neurons := Trie.put(neurons, key(msg.caller), Principal.equal, newNeuron).0;
                    return "Neuron created";
                    }; 
            case(?neuron){
                //updates old neuron with new tokens, and increases delay, if set to larger
                let newNeuron : Neuron = {dissolveDelay = Int.max(neuron.dissolveDelay, delay);
                    creationTime = Time.now();
                    tokenAmount = tokenBalance;
                    dissolving = neuron.dissolving;
                    subAccountBlob = neuron.subAccountBlob;
                    dissolvingLastTimeStamp = neuron.dissolvingLastTimeStamp;};
                    neurons := Trie.put(neurons, key(msg.caller), Principal.equal, newNeuron).0;
                    return "Neuron updatded";
                    };
            };
        };

    public shared (msg) func dissolveNeuron() : async Text{
        let neuron = Trie.get(neurons, key(msg.caller), Principal.equal);
        switch(neuron){
            case(null){return "No neuron to dissolve"};
            case(?x){
                if(x.dissolveDelay < (Time.now() - x.dissolvingLastTimeStamp)){
                    //return the tokens to owner
                    let userAcc : Account = {owner = msg.caller; subaccount = null};
                    let args : TransferArgs = {amount = x.tokenAmount; created_at_time = Prim.time(); 
                        fee = ?10; from_subaccount = ?x.subAccountBlob;
                        memo = x.subAccountBlob; to = userAcc};
                    
                    ignore await mbtCanister.icrc1_transfer(args);
                    ignore Trie.remove(neurons, key(msg.caller), Principal.equal);
                    return "tokens sent back to user (not functioning rn)"
                };
                if(x.dissolving == true){
                    let newNeuron : Neuron = {
                        dissolveDelay = x.dissolveDelay - (Time.now()- x.dissolvingLastTimeStamp);
                        creationTime = x.creationTime;
                        tokenAmount = x.tokenAmount;
                        subAccountBlob = x.subAccountBlob;
                        dissolving = true;
                        dissolvingLastTimeStamp = Time.now();
                    };
                    neurons := Trie.put(neurons, key(msg.caller), Principal.equal, newNeuron).0;
                    return "dissolvingDelay updated to " # Int.toText(x.dissolveDelay);

                    } else {
                        let newNeuron : Neuron = {
                            dissolveDelay = x.dissolveDelay;
                            creationTime = x.creationTime;
                            tokenAmount = x.tokenAmount;
                            subAccountBlob = x.subAccountBlob;
                            dissolving = true;
                            dissolvingLastTimeStamp = Time.now();
                        };
                        neurons := Trie.put(neurons, key(msg.caller), Principal.equal, newNeuron).0;
                        return "dissolving for " # Int.toText(x.dissolveDelay);
                };
        };
        };

    };

  type Subaccount = Blob;
  type Account = { owner : Principal; subaccount : ?Subaccount; };
  
    type TransferError = {
    BadFee : { expected_fee : Nat };
    BadBurn : { min_burn_amount : Nat };
    InsufficientFunds : { balance : Nat };
    TooOld : {};
    CreatedInFuture : { ledger_time: Nat64 };
    Duplicate : { duplicate_of : Nat };
    TemporarilyUnavailable :{};
    GenericError : { error_code : Nat; message : Text };
};
    type TransferArgs = {
    from_subaccount : ?Subaccount;
    to : Account;
    amount : Nat;
    fee : ?Nat;
    memo : Blob;
    created_at_time : Nat64;
};  
    type Vote = {#no; #yes};
    type Proposal = {
        //Text is pushed to frontend if vote is passed
        quadratic : Bool;
        passed : Bool;
        minimumVote : Float;
        info : Text;
        passLimit : Float;
        id : Nat;
        votedFor : List.List<Principal>;
        votedAgainst : List.List<Principal>;
    };
    type Neuron = {
        //Use same time unit for all
        subAccountBlob : Blob;
        dissolveDelay : Int;
        creationTime : Int;
        tokenAmount : Nat;
        dissolving : Bool;
        dissolvingLastTimeStamp : Int;
    };
    }