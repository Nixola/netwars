-- vim:et

chat={
chatq=queue(10);
input=false;
timeout=5.0;
}

local buf={}
local str=""

function chat.enter()
  buf={}
  if str:len()>100 or str:len()<1 then
    str=""
    return false
  end
  if str:match("[%a%d_\\ :;`\"\'%,%.%<%>%(%)%[%]%{%}%/%?%!%@%#%$%%%^%&%*%-%+]*")~=str then
    str=""
    return false
  end
  net_send("MSG:~%s",str)
  str=""
  return false
end

function chat.keypressed(key,ch)
  if key=="escape" then
    buf={}
    str=""
    return false
  end
  if key=="return" then
    return chat.enter()
  end
  if key=="backspace" then
    table.remove(buf)
    str=table.concat(buf)
    return true
  end
  if ch<32 or ch>127 then
    return true
  end
  if table.maxn(buf)<100 then
    table.insert(buf,string.char(ch))
    str=table.concat(buf)
  end
  return true
end

function chat.draw()
  local y=5
  graph.setColor(255,255,255)
  if chat.input then
    graph.print(string.format("> %s",str),5,eye.sy-70)
  end
  for m in chat.chatq:iter() do
    graph.print(m,5,y)
    y=y+15
  end
end

local my_dt=0
function chat.update(dt)
  if chat.chatq.len<1 then
    my_dt=0
    return
  end
  my_dt=my_dt+dt
  if my_dt<chat.timeout then
    return
  end
  my_dt=my_dt-chat.timeout
  chat.chatq:del()
end
