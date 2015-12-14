%% -------------------------------------------------------------------
%% ya_crdt.erl behaviour of CRDTs
%% -------------------------------------------------------------------
-module(ya_crdt).

%% API exports
-export_type([crdt/0, operation/0, status/0]).

%% TYPES
-type crdt() :: term().
-type operation() :: term().
-type status() :: atom().

%% INTERFACE
-callback init() -> crdt().
-callback query(crdt()) -> [term()].
-callback query(term(), crdt()) -> crdt().
-callback update(operation(), term(), crdt()) -> {status(), crdt()}.
%% @doc Semilattice comparison of two CRDTs
%% General Lattice Laws:
%% A lattice is a partially ordered set that is both a meet- and join-semilattice
%% with respect to the same partial order.
%% let v = union
%% let ^ = intersection
%% let A, B and C be crdts
%% Commutative laws:
%%    A v B = B v A
%%    A ^ B = B ^ A
%% Associative laws:
%%    A v (B v C) = (A v B) v C
%%    A ^ (B ^ C) = (A ^ B) ^ C
%% Absorption laws:
%%    A v (A ^ B) = A
%%    A ^ (A v B) = A
%% Identity laws:
%%    A v 0 = A
%%    A ^ A = A
%% join-semilattice (or upper semilattice) is a partially ordered set
%% that has a join (a least upper bound) for any nonempty finite subset.
%% Dually, a meet-semilattice (or lower semilattice) is a partially ordered set
%% which has a meet (or greatest lower bound) for any nonempty finite subset.
%% Every join-semilattice is a meet-semilattice in the inverse order and vice versa.
%% Meet-Semilattice
%% - A set (S) partially ordered by the binary relation ≤ is a meet-semilattice if
%%   -  For all elements x and y of (S), the greatest lower bound of the set {x, y} exists.
%% Join-Semilattice
%% - A set (S) partially ordered by the binary relation ≤ is a join-semilattice if
%%   -  For all elements x and y of (S), the leas upper bound of the set {x, y} exists.
-callback compare(crdt(), crdt()) -> boolean().
%% @doc
%% Least Upper Bound merge of crdt1 and crdt2, at any replica with respect to information content
%% I.e. merge the information available in each.
%% For flat types (in which all values are either bottom or fully defined).
%% See compare for rules about CRDTs comparison
-callback merge(crdt(), crdt()) -> crdt().

%%====================================================================
%% API functions
%%====================================================================


%%====================================================================
%% Internal functions
%%====================================================================
