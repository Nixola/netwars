-- vim:et

local function history(sz)
  local object={}
  object.size=sz or 1000
  object.len=0
  function object:push(str)
    if self.len>=self.size then
      self:del()
    end
    local t={}
    t.val=str
    self.len=self.len+1
    if not self.head then
      self.head=t
      self.tail=t
      return false
    end
    t.link=self.head
    t.link.prev=t
    self.head=t
    return true
  end
  function object:del()
    if self.tail then
      local t=self.tail
      self.len=self.len-1
      if t.prev then
        self.tail=t.prev
      else
        self.head=nil
        self.tail=nil
        self.len=0
      end
    end
  end
  function object:iter(_n)
    local i=self.head
    local n=_n
    return function()
      while i and n>0 do
        i=i.link
        n=n-1
      end
      if i then
        local v=i.val
        i=i.link
        return v
      end
      return nil
    end
  end
  function object:clear()
    self.head=nil
    self.tail=nil
    self.len=0
  end
  return object
end

chat={
chatq=queue(5);
hist=history();
input=false;
console=false;
timeout=5.0;
}

local buf={}
local str=""

function chat.enter()
  buf={}
  if str:len()>100 or str:len()<1 then
    str=""
    return chat.console
  end
  if str:match("[%a%d_\\ :;\"\'%,%.%<%>%(%)%[%]%{%}%/%?%!%@%#%$%%%^%&%*%-%+]*")~=str then
    str=""
    return chat.console
  end
  net_send("MSG:~%s",str)
  str=""
  return chat.console
end

local con_skip=0
local skipv
function chat.keypressed(key,ch)
  skipv=math.floor(eye.cy/15/2)
  if key=="escape" then
    buf={}
    str=""
    return chat.console
  end
  if key=="return" then
    return chat.enter()
  end
  if chat.console then
    if key=="`" then
      chat.console=false
      buf={}
      str=""
      return false
    end
    if key=="pageup" then
      if chat.hist.len>skipv then
        con_skip=con_skip+skipv
        if con_skip>chat.hist.len-skipv then
          con_skip=chat.hist.len-skipv
        end
      end
      return true
    end
    if key=="pagedown" then
      con_skip=con_skip-skipv
      if con_skip<0 then
        con_skip=0
      end
      return true
    end
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

local con_off=0
function chat.draw()
  if chat.console or con_off>0 then
    graph.setColor(0,0,96,192)
    graph.setLine(1,"rough")
    graph.rectangle("fill",0,0,eye.sx-1,con_off)
    graph.setColor(64,64,192)
    graph.line(0,con_off,eye.sx-1,con_off)
    graph.setColor(255,255,255)
    local y=con_off-20
    graph.print(string.format("> %s",str),5,y)
    y=y-20
    for m in chat.hist:iter(con_skip) do
      if y<5 then
        break
      end
      graph.print(m,5,y)
      y=y-15
    end
    return
  end
  graph.setColor(255,255,255)
  if chat.input then
    graph.print(string.format("> %s",str),5,eye.sy-70)
  end
  local y=5
  for m in chat.chatq:iter() do
    graph.print(m,5,y)
    y=y+15
  end
end

local my_dt=0
function chat.update(dt)
  local offv=eye.cy/0.3
  if chat.console then
    if con_off<eye.cy then
      con_off=math.floor(con_off+offv*dt)
      if con_off>eye.cy then
        con_off=eye.cy
      end
    end
  else
    if con_off>0 then
      con_off=math.floor(con_off-offv*dt)
      if con_off<0 then
        con_off=0
        con_skip=0
      end
    end
  end
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

function chat.msg(str)
  chat.chatq:push(str)
  chat.hist:push(str)
  if chat.chatq.len>=chat.chatq.size then
    my_dt=0
  end
end
