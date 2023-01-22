export const idlFactory = ({ IDL }) => {
  const List = IDL.Rec();
  List.fill(IDL.Opt(IDL.Tuple(IDL.Principal, List)));
  const Proposal = IDL.Record({
    'id' : IDL.Nat,
    'votedFor' : List,
    'info' : IDL.Text,
    'minimumVote' : IDL.Float64,
    'passLimit' : IDL.Float64,
    'votedAgainst' : List,
    'quadratic' : IDL.Bool,
    'passed' : IDL.Bool,
  });
  return IDL.Service({
    'checkVotingResult' : IDL.Func([IDL.Int], [IDL.Text], []),
    'createNeuron' : IDL.Func([IDL.Int], [IDL.Text], []),
    'dissolveNeuron' : IDL.Func([], [IDL.Text], []),
    'get_all_proposals' : IDL.Func(
        [],
        [IDL.Vec(IDL.Tuple(IDL.Int, Proposal))],
        ['query'],
      ),
    'get_proposal' : IDL.Func([IDL.Int], [IDL.Opt(Proposal)], ['query']),
    'modify_parameters' : IDL.Func(
        [IDL.Nat, IDL.Opt(IDL.Float64), IDL.Opt(IDL.Bool), IDL.Opt(IDL.Text)],
        [IDL.Text],
        [],
      ),
    'submit_proposal' : IDL.Func(
        [IDL.Text],
        [IDL.Variant({ 'Ok' : Proposal, 'Err' : IDL.Text })],
        [],
      ),
    'vote' : IDL.Func(
        [IDL.Int, IDL.Bool],
        [IDL.Variant({ 'Ok' : IDL.Tuple(IDL.Nat, IDL.Nat), 'Err' : IDL.Text })],
        [],
      ),
  });
};
export const init = ({ IDL }) => { return []; };
