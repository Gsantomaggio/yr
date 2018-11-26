%%%-------------------------------------------------------------------
%%% @author GaS
%%% @copyright (C) 2018, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 26. Aug 2018 16:06
%%%-------------------------------------------------------------------
-module(yr_reg).
-author("GaS").

-behaviour(gen_statem).

%% API
-export([start_link/0]).

%% gen_statem callbacks
-export([
    init/1,
    handle_event/4,
    terminate/3,
    code_change/4
    , callback_mode/0, register/2, whereis/1, unregister/1, processes/0]).

-define(SERVER, ?MODULE).

-include_lib("stdlib/include/ms_transform.hrl").
-record(state, {reg_table, ps_table}).

%%%===================================================================
%%% API
%%%===================================================================

register(Atom, PID) ->
    gen_statem:call(?SERVER, {register, Atom, PID}).

unregister(Atom) ->
    gen_statem:call(?SERVER, {unregister, Atom}).


whereis(Atom) ->
    gen_statem:call(?SERVER, {whereis, Atom}).


processes() ->
    gen_statem:call(?SERVER, {processes}).

%%--------------------------------------------------------------------
%% @doc
%% Creates a gen_statem process which calls Module:init/1 to
%% initialize. To ensure a synchronized start-up procedure, this
%% function does not return until Module:init/1 has returned.
%%
%% @spec start_link() -> {ok, Pid} | ignore | {error, Error}
%% @end
%%--------------------------------------------------------------------
start_link() ->
    gen_statem:start_link({local, ?SERVER}, ?MODULE, [], []).

%%%===================================================================
%%% gen_statem callbacks
%%%===================================================================

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Whenever a gen_statem is started using gen_statem:start/[3,4] or
%% gen_statem:start_link/[3,4], this function is called by the new
%% process to initialize.
%%
%% @spec init(Args) -> {CallbackMode, StateName, State} |
%%                     {CallbackMode, StateName, State, Actions} |
%%                     ignore |
%%                     {stop, StopReason}
%% @end
%%--------------------------------------------------------------------
init([]) ->
    {ok, lazy_init, #state{}}.


callback_mode() ->
    handle_event_function.


handle_event({call, From}, N, lazy_init, State) ->
    T = ets:new(reg_table, [duplicate_bag, public, named_table]),
    PS = ets:new(ps_table, [duplicate_bag, public, named_table]),
    error_logger:info_report([{init, N}]),
    {next_state, ready, State#state{reg_table = T, ps_table = PS},
        [{next_event, {call, From}, N}]};
handle_event({call, From}, {register, Atom, PID}, ready, State = #state{reg_table = T}) when is_pid(PID) ->
    case ets:lookup(T, Atom) of
        [] ->
            Ref = erlang:monitor(process, PID),
            R = ets:insert(reg_table, {Atom, PID, Ref}),
            {keep_state, State, [{reply, From, {ok, R}}]};
        [{_, PID_TABLE}] ->
            error_logger:info_report([{error_report, PID_TABLE}]),
            {keep_state, State, [{reply, From, {error, PID_TABLE}}]}
    end;
handle_event({call, From}, {register, _Atom, _PID}, ready, State) ->
    {keep_state, State, [{reply, From, {error, not_valid_pid}}]};

handle_event({call, From}, {unregister, Atom}, ready, State = #state{reg_table = T}) ->
    case ets:lookup(T, Atom) of
        [] ->
            {keep_state, State, [{reply, From, {error, Atom}}]};
        [{_, PID_TABLE, Ref}] ->
            erlang:demonitor(Ref, [flush]),
            ets:delete(T, Atom),
            {keep_state, State, [{reply, From, {ok, PID_TABLE}}]}
    end;
handle_event({call, From}, {whereis, Atom}, ready, State) ->
    case ets:lookup(reg_table, Atom) of
        [] -> {keep_state, State, [{reply, From, {error, Atom}}]};
        [{_, PID_TABLE, _}] ->
            {keep_state, State, [{reply, From, PID_TABLE}]}
    end;
handle_event({call, From}, {processes}, ready, State = #state{reg_table = T}) ->
    {keep_state, State, [{reply, From, {ok, ets:select(T, ets:fun2ms(fun(N) -> N end))}}]};
handle_event(info, {'DOWN', _MonitorReference, process, Pid, Reason}, ready, State = #state{reg_table = T}) ->
    error_logger:info_report([{down, Pid}, {reason, Reason}]),
    [{Atm, Rf}] = ets:select(T, ets:fun2ms(fun({Atom, PidL, Ref}) when PidL =:= Pid -> {Atom, Ref} end)),
    erlang:demonitor(Rf, [flush]),
    ets:delete(T, Atm),
    {keep_state, State, []}.

terminate(_Reason, _StateName, _State) ->
    ok.

code_change(_OldVsn, StateName, State, _Extra) ->
    {ok, StateName, State}.
