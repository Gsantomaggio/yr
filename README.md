Yes another Erlang Registry
---

This is just a test program.

Example:

```
> FM= fun R()->receive
{msg, MSG} -> io:format("got message:~p~n",[MSG]), R();
{close} -> io:format("Goodbye:~n",[])
end end.

> yr_reg:register(ps,spawn(FM)). 

> yr_reg:whereis(ps) ! {msg, "hello"}.
got message:"hello"


> yr_reg:processes().
{ok,[{ps,<0.285.0>,#Ref<0.109273322.795607042.176688>}]}


> yr_reg:unregister(ps).
 
 

```