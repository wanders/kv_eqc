%% This file contains an implementation of a simple key-value store,
%% and a state-machine specification of it.

-module(kv).

-include_lib("eqc/include/eqc.hrl").
-include_lib("eqc/include/eqc_statem.hrl").

-compile(export_all).

%% The key-value store is managed by a server, and implemented as a binary tree.

start() ->
  catch unregister(kv),
  register(kv,spawn_link(fun() -> server(leaf) end)).

server(T) ->
  receive
    {insert,K,V} ->
      server(insert(K,V,T));
    {lookup,K,Pid} ->
      Pid ! lookup(K,T),
      server(T)
  after 5000 ->
      %% Our server dies after 5 seconds of inactivity... just so we
      %% don't fill the memory with idle servers.
      ok
  end.

insert(K,V,leaf) ->
  {node,leaf,K,V,leaf};
insert(K,V,{node,L,KN,_VN,R}) ->
  if K<KN ->
      insert(K,V,L);
     K==KN ->
      {node,L,K,V,R};
     K>KN ->
      insert(K,V,R)
  end.

lookup(_,leaf) ->
  false;
lookup(K,{node,L,KN,VN,R}) ->
  if K<KN ->
      lookup(K,R);
     K==KN ->
      {K,VN};
     K>KN ->
      lookup(K,L)
  end.

%% State machine

initial_state() ->
  [].

%% insert

insert(K,V) ->
  kv ! {insert,K,V}.

insert_args(_) ->
  [key(),val()].

insert_next(S,_,[K,V]) ->
  lists:keystore(K,1,S,{K,V}).

%% lookup

lookup(K) ->
  kv ! {lookup,K,self()},
  receive Msg ->
       Msg
  end.

lookup_args(_) ->
  [key()].

lookup_post(S,[K],Res) ->
  eq(Res,lists:keyfind(K,1,S)).

%% Generators

key() ->
  nat().

val() ->
  nat().

%% Property

prop_kv() ->
  ?FORALL(Cmds, commands(?MODULE),
          begin
            start(),
            {H, S, Res} = run_commands(?MODULE,Cmds),
            pretty_commands(?MODULE, Cmds, {H, S, Res},
                            aggregate(command_names(Cmds),
                                      ?IMPLIES(Res/=precondition,
                                               Res == ok)))
          end).
