import Text "mo:base/Text";
import Http "./http";
import Array "mo:base/Array";
import List "mo:base/List";
import Principal "mo:base/Principal";

actor c1{
    public type HttpRequest = Http.HttpRequest;
    public type HttpResponse = Http.HttpResponse;
    let allowList : Principal = Principal.fromText("dzs5h-6iaaa-aaaal-qbsha-cai");
    stable var proposals : Text = "Okey, lets go! ";
    public shared (msg) func updateProposal(text : Text) : async Text{
        if(msg.caller == allowList){
        proposals := text;        
    };
    return "okey";
    };
    public query func http_request(req : HttpRequest) : async HttpResponse{
        return ({
            body = Text.encodeUtf8(proposals);
            headers = [];
            status_code = 200;
            streaming_strategy = null;
        });
    };
    type Proposal = {
        //Text is pushed to frontend if vote is passed
        passed : Bool;
        info : Text;
        id : Nat;
        votedFor : List.List<Principal>;
        votedAgainst : List.List<Principal>;
    };
}