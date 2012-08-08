-- vim:et

require "readline"

local function history(sz)
  local object={}
  object.size=sz or 1000
  object.len=0
  object.offp=nil
  object.offv=0
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
        self.tail.link=nil
      else
        self.head=nil
        self.tail=nil
        self.offp=nil
        self.offv=0
        self.len=0
      end
    end
  end
  function object:set_off(n,s)
    if not n or n<=0 then
      self.offp=nil
      self.offv=0
      return
    end
    if s>=self.len then
      self.offp=nil
      self.offv=0
      return
    end
    if n>self.len-s then
      n=self.len-s
    end
    local i=self.head
    self.offv=n
    while i and n>0 do
      i=i.link
      n=n-1
    end
    self.offp=i
  end
  function object:iter()
    local i=self.offp or self.head
    return function()
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
    self.offp=nil
    self.offv=0
    self.len=0
  end
  return object
end

local chatq=queue(5)
local histq=history()
local readline=Readline:new(100)

chat={
input=false;
console=false;
timeout=5.0;
}

local buf={}
local str=""

function chat.enter()
  buf={}
  if readline.str:len()>readline.sz or readline.str:len()<1 then
    readline:clr()
    return chat.console
  end
  if readline.str:match("[%a%d_\\ :;\"\'%,%.%<%>%(%)%[%]%{%}%/%?%!%@%#%$%%%^%&%*%-%+%=]*")~=readline.str then
    readline:clr()
    return chat.console
  end
  net_send("MSG:~%s",readline.str)
  readline:clr()
  return chat.console
end

function chat.keypressed(key,ch)
  if key=="escape" then
    readline:clr()
    return chat.console
  end
  if key=="return" then
    return chat.enter()
  end
  if chat.console then
    local step=floor((eye.cy-25)/15/2)
    if key=="`" then
      chat.console=false
      readline:clr()
      return false
    end
    if key=="pageup" then
      histq:set_off(histq.offv+step,step)
      return true
    end
    if key=="pagedown" then
      histq:set_off(histq.offv-step,step)
      return true
    end
  end
  readline:key(key,ch)
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
    local y=con_off-20
    readline:draw(5,y,"> ")
    y=y-20
    graph.setColor(255,255,255)
    for m in histq:iter() do
      if y<5 then
        break
      end
      graph.print(m,5,y)
      y=y-15
    end
    return
  end
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
  if chat.console then
    if con_off<eye.cy then
      con_off=floor(con_off+offv*dt)
      if con_off>eye.cy then
        con_off=eye.cy
      end
    end
  else
    if con_off>0 then
      con_off=floor(con_off-offv*dt)
      if con_off<0 then
        con_off=0
        histq:set_off()
      end
    end
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
  histq:push(str)
  if chatq.len>=chatq.size then
    my_dt=0
  end
end
