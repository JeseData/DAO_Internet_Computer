import type { Principal } from '@dfinity/principal';
import type { ActorMethod } from '@dfinity/agent';

export type List = [] | [[Principal, List]];
export interface Proposal {
  'id' : bigint,
  'votedFor' : List,
  'info' : string,
  'minimumVote' : number,
  'passLimit' : number,
  'votedAgainst' : List,
  'quadratic' : boolean,
  'passed' : boolean,
}
export interface _SERVICE {
  'checkVotingResult' : ActorMethod<[bigint], string>,
  'createNeuron' : ActorMethod<[bigint], string>,
  'dissolveNeuron' : ActorMethod<[], string>,
  'get_all_proposals' : ActorMethod<[], Array<[bigint, Proposal]>>,
  'get_proposal' : ActorMethod<[bigint], [] | [Proposal]>,
  'modify_parameters' : ActorMethod<
    [bigint, [] | [number], [] | [boolean], [] | [string]],
    string
  >,
  'submit_proposal' : ActorMethod<
    [string],
    { 'Ok' : Proposal } |
      { 'Err' : string }
  >,
  'vote' : ActorMethod<
    [bigint, boolean],
    { 'Ok' : Proposal } |
      { 'Err' : string }
  >,
}
