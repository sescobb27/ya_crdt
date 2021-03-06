%% -------------------------------------------------------------------
%% ya_orset.erl Implementation of Observed-Remove Set
%% OR-Set is a CRDT. Concurrent adds commute since each one is unique. Concurrent
%% removes commute because any common pairs have the same effect, and any disjoint pairs
%% have independent effects. Concurrent add(e) and remove(f) also commute: if e != f they
%% are independent, and if e = f the remove has no effect.
%% USAGE:
% Set = ya_orset:init().
% {ok, Set1} = ya_orset:update(add, <<"foo">>, Set).
% {ok, Set2} = ya_orset:update(add, <<"foo">>, Set1).
% {ok, Set3} = ya_orset:update(add, <<"bar">>, Set2).
% {ok, Set4} = ya_orset:update(remove, <<"foo">>, Set3).
%% -------------------------------------------------------------------
-module(ya_orset).

-behaviour(ya_crdt).

%% API exports
-export([
    init/0,
    query/1,
    query/2,
    update/3,
    compare/2,
    merge/2
  ]).

%%====================================================================
%% API functions
%%====================================================================
%% @doc ORSet consists of a set of pairs
%% {element, ORSet#{{Token => Operation}, {...}}.
-spec init() -> ya_crdt:crdt().
init() -> orddict:new().

%% @doc query extracts elements e from the pairs who have not been removed
-spec query(ya_crdt:crdt()) -> [term()].
query(ORSet) ->
  NonRemovedElements = orddict:filter(fun(_Elem, ORSetTokens) ->
    UpdateHistory = [Token || {Token, add} <- orddict:to_list(ORSetTokens)],
    length(UpdateHistory) >= 0
  end, ORSet),
  orddict:fecth_keys(NonRemovedElements).

-spec query(term(), ya_crdt:crdt()) -> ya_crdt:crdt().
query(Elem, ORSet) ->
  case orddict:find(Elem, ORSet) of
    {ok, ORSetTokens} ->
      ORSetTokens;
    error -> orddict:new()
  end.

%% @doc generates a unique identifier in the source replica,
%% which is then propagated to downstream replicas,
%% which insert the pair into their payload.
%% e.g Two add operations generate two unique pairs,
%% but query masks the duplicates.
-spec update(ya_crdt:operation(), term(), ya_crdt:crdt()) -> {ya_crdt:status(), ya_crdt:crdt()}.
update(add, [H|Tail] = Elem, ORSet) when is_list(Elem) ->
  UniqueToken = crypto:strong_rand_bytes(20),
  add_element(UniqueToken, H, ORSet),
  update(add, Tail, ORSet);

update(add, [], ORSet) ->
  ORSet;

update(add, Elem, ORSet) ->
  UniqueToken = crypto:strong_rand_bytes(20),
  add_element(UniqueToken, Elem, ORSet);

%% @doc When a client calls remove(e) at some source, the set of unique tags associated with e at
%% the source is recorded. Downstream, all such pairs are removed from the local payload. Thus,
%% when remove(e) happens-after any number of add(e), all duplicate pairs are removed, and
%% the element is not in the set any more, as expected intuitively. When add(e) is concurrent
%% with remove(e), the add takes precedence, as the unique tag generated by add cannot be
%% observed by remove.
update(remove, [H|Tail]=Elem, ORSet) when is_list(Elem) ->
  remove_element(H, ORSet),
  update(remove, Tail, ORSet);

update(remove, [], ORSet) ->
  {ok, ORSet};

update(remove, Elem, ORSet) ->
  remove_element(Elem, ORSet).

-spec compare(ya_crdt:crdt(), ya_crdt:crdt()) -> boolean().
compare(ORSet1, ORSet2) ->
  ORSet1 == ORSet2.

%% @doc Concurrent adds commute since each one is unique. Concurrent
%% removes commute because any common pairs have the same effect, and any disjoint pairs
%% have independent effects. Concurrent add(e) and remove(f) also commute: if e != f they
%% are independent, and if e = f the remove has no effect.
-spec merge(ya_crdt:crdt(), ya_crdt:crdt()) -> {ya_crdt:status(), ya_crdt:crdt()}.
merge(ORSet1, ORSet2) ->
  MergeTokensFun = fun(_Token, Operation1, Operation2) ->
    case {Operation1, Operation2} of
      {add, _} -> add;
      {_, add} -> add;
      _Else -> remove
    end
  end,
  MergeORSetFun = fun(_Elem, ORSetTokens1, ORSetTokens2) ->
    orddict:merge(MergeTokensFun, ORSetTokens1, ORSetTokens2)
  end,
  orddict:merge(MergeORSetFun, ORSet1, ORSet2).

%%====================================================================
%% Internal functions
%%====================================================================
%% @doc Add #{Elem => Token} to ORSet#{Element => ORset#{[Token]}}
%% Find Elem inside ORSet, if it was found Add new Token to its Token's Set,
%% otherwise Create a new ORSet and Add new Token to it. Then return the newly
%% updated ORSet#{Elem => ORSet#{[Token, add], ...}}.
-spec add_element(term(), term(), ya_crdt:crdt()) -> {ya_crdt:status(), ya_crdt:crdt()}.
add_element(Token, Elem, ORSet) ->
  case orddict:find(Elem, ORSet) of
    {ok, ORSetTokens} ->
      ORSetNewTokens = orddict:store(Token, add, ORSetTokens),
      {ok, orddict:store(Elem, ORSetNewTokens, ORSet)};
    error ->
      ORSetNewTokens = orddict:store(Token, add, orddict:new()),
      {ok, orddict:store(Elem, ORSetNewTokens, ORSet)}
  end.

%% @doc Remove elem from ORSet, if it was found create a new ORSet which all
%% its tokens are removed, then add those tokens to the ORSet,
%% otherwise return {error, ORSet} untouched
-spec remove_element(term(), ya_crdt:crdt()) -> {ya_crdt:status(), ya_crdt:crdt()}.
remove_element(Elem, ORSet) ->
  case orddict:find(Elem, ORSet) of
    {ok, ORSetTokens} ->
      ORSetNewTokens = orddict:fold(fun (Token, _Operation, NewORSet) ->
        orddict:store(Token, remove, NewORSet)
      end, orddict:new(), ORSetTokens),
      {ok, orddict:store(Elem, ORSetNewTokens, ORSet)};
    error -> {error, ORSet}
  end.
