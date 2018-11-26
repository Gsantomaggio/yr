%%%-------------------------------------------------------------------
%%% @author GaS
%%% @copyright (C) 2018, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 26. Aug 2018 15:58
%%%-------------------------------------------------------------------
-module(yr).
-export([start/0]).

start() ->
    application:ensure_all_started(?MODULE).
