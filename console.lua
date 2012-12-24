-- vim:et

require "chat"

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

local histq=history()
local readline=Readline:new(100)

console={
input=false;
}

local function split(str)
  local a={}
  local l=str:len()
  local n=0
  local p=1
  local q=str:find(" ",1,true)
  while q do
    a[#a+1]=str:sub(p,q-1)
    q=q+n
    while str:sub(q,q)==" " do
      q=q+1
    end
    if str:sub(q,q)=="\"" then
      p=q+1
      q=str:find("\"",p,true)
      n=1
    else
      p=q
      q=str:find(" ",p,true)
      n=0
    end
  end
  if p<=l then
    a[#a+1]=str:sub(p,l)
  end
  return a
end

function console.cmd(str)
  arg=split(str)
  if arg[1]=="/graph" then
    if #arg<2 then
      histq:push("graph: not enough arguments")
      return
    end
    a=str_split(arg[2],"x")
    if a.n<2 then
      histq:push("graph: bad arguments")
      return
    end
    conf.graph_width=tonumber(a[1])
    conf.graph_height=tonumber(a[2])
    save_conf()
    set_graph()
    init_graph()
    init_gui()
    return
  end
  if arg[1]=="/set" then
    if #arg<2 then
      histq:push("set: not enough arguments")
      return
    end
    if arg[2]=="chat_timeout" then
      if #arg<3 then
        histq:push(string.format("chat_timeout=%s",conf.chat_timeout))
        return
      end
      conf.chat_timeout=tonumber(arg[3])
      save_conf()
      return
    end
  end
  histq:push("unknown command")
end

function console.enter()
  if readline.str:len()>readline.sz or readline.str:len()<1 then
    readline:clr()
    return
  end
  if readline.str:match("[%a%d_\\ :;\"\'%,%.%<%>%(%)%[%]%{%}%/%?%!%@%#%$%%%^%&%*%-%+%=]*")~=readline.str then
    readline:clr()
    return
  end
  if readline.str:sub(1,1)=="/" then
    console.cmd(readline.str)
    readline:clr()
    return
  end
  chat.send(readline.str)
  readline:clr()
  return
end

function console.keypressed(key,ch)
  local step=floor((eye.cy-25)/15/2)
  if key=="escape" then
    readline:clr()
    return true
  end
  if key=="return" then
    console.enter()
    return true
  end
  if key=="`" then
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
  readline:key(key,ch)
  return true
end

local con_off=0
function console.draw()
  if con_off>0 then
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
  chat.draw()
end

local cr_dt=0
local my_dt=0
function console.update(dt)
  local offv=eye.cy/0.3
  cr_dt=cr_dt+dt
  if cr_dt>=0.5 then
    cr_dt=cr_dt-0.5
    readline.cr=not readline.cr
  end
  if console.input then
    if con_off<eye.cy then
      con_off=floor(con_off+offv*dt)
    end
    if con_off>eye.cy then
      con_off=eye.cy
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
  chat.update(dt)
end

function console.msg(str)
  histq:push(str)
  chat.msg(str)
end