-- vim:et

require "readline"

local chatq=queue(5)
local readline=Readline:new(100)

chat={
input=false;
timeout=5.0;
}

function chat.send(str)
  if ME and not replay then
    net_send("MSG:~%s",str)
  end
end

function chat.enter()
  if readline.str:len()>readline.sz or readline.str:len()<1 then
    readline:clr()
    return
  end
  if readline.str:match("[%a%d_\\ :;\"\'%,%.%<%>%(%)%[%]%{%}%/%?%!%@%#%$%%%^%&%*%-%+%=]*")~=readline.str then
    readline:clr()
    return
  end
  chat.send(readline.str)
  readline:clr()
  return
end

function chat.keypressed(key,ch)
  if key=="escape" then
    readline:clr()
    return false
  end
  if key=="return" then
    chat.enter()
    return false
  end
  readline:key(key,ch)
  return true
end

local con_off=0
function chat.draw()
  if chat.input then
    readline:draw(5,eye.sy-70,"> ")
  end
  local y=5
  graph.setColor(255,255,255)
  for m in chatq:iter() do
    graph.print(m,5,y)
    y=y+15
  end
end

local cr_dt=0
local my_dt=0
function chat.update(dt)
  local offv=eye.cy/0.3
  cr_dt=cr_dt+dt
  if cr_dt>=0.5 then
    cr_dt=cr_dt-0.5
    readline.cr=not readline.cr
  end
  if chatq.len<1 then
    my_dt=0
    return
  end
  my_dt=my_dt+dt
  if my_dt>=chat.timeout then
    my_dt=my_dt-chat.timeout
    chatq:del()
  end
end

function chat.msg(str)
  chatq:push(str)
  if chatq.len>=chatq.size then
    my_dt=0
  end
end
