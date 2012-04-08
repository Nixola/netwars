-- vim:et

function class(name)
  local newclass={}
  _G[name]=newclass
  newclass.class=name
  newclass.__members={}
  function newclass.define(class,members)
    for k,v in pairs(members) do
      class.__members[k]=v
    end
  end
  function newclass.extends(class,base)
    class.__super=base
    for k,v in pairs(base.__members) do
      class.__members[k]=v
    end
    return setmetatable(class,{__index=base,__call=class.define})
  end
  function newclass.new(class,...)
    if class.__class then
      return class.__class:new(...)
    end
    local object={}
    object.__class=class
    for k,v in pairs(class.__members) do
      object[k]=v
    end
    setmetatable(object,{__index=class})
    if object.initialize then
      object:initialize(...)
    end
    return object
  end
  function newclass.super(class,func,...)
    local oldcl=class.__supcl
    if oldcl then
      local supcl=oldcl.__super
      local chunk=rawget(supcl,func)
      while not chunk do
        supcl=supcl.__super
        chunk=rawget(supcl,func)
      end
      class.__supcl=supcl
      local ret=chunk(class,...)
      class.__supcl=oldcl
      return ret
    end
    local supcl=class.__class
    local chunk=rawget(supcl,func)
    while not chunk do
      supcl=supcl.__super
      chunk=rawget(supcl,func)
    end
    supcl=supcl.__super
    chunk=rawget(supcl,func)
    while not chunk do
      supcl=supcl.__super
      chunk=rawget(supcl,func)
    end
    class.__supcl=supcl
    local ret=chunk(class,...)
    class.__supcl=nil
    return ret
  end
  return setmetatable(newclass,{__call=newclass.define})
end

local mt_storage={}
function mt_storage:add(o)
  rawset(self,o,o)
end
function mt_storage:del(o)
  rawset(self,o,nil)
end
function mt_storage:find(o)
  return rawget(self,o)
end
function storage()
  local t={}
  setmetatable(t,{__index=mt_storage})
  return t
end

local mt_ctable={}
function mt_ctable:add(o)
  local idx=#self+1
  o.__idx=idx
  self[idx]=o
  return idx
end
function mt_ctable:del(o)
  local idx=o.__idx
  o.__idx=nil
  self[idx]=nil
  return idx
end
function mt_ctable:find(o)
  local idx=o.__idx
  if self[idx]==o then
    return idx
  end
  return nil
end
function ctable()
  local t={}
  setmetatable(t,{__index=mt_ctable})
  return t
end

function str_split(str,sep)
  local a={}
  local l=str:len()
  local p=1
  local q=str:find(sep,1,true)
  while q do
    a[#a+1]=str:sub(p,q-1)
    p=q+1
    if str:sub(p,p)=="~" then
      p=p+1
      break
    end
    q=str:find(sep,p,true)
  end
  a[#a+1]=str:sub(p,l)
  a.n=#a
  return a
end

function queue(sz)
  local object={}
  object.size=sz or 100
  object.len=0
  function object:put(str)
    if self.len>=self.size then
      return nil
    end
    local t={}
    t.val=str
    self.len=self.len+1
    if not self.tail then
      self.head=t
      self.tail=t
      return false
    end
    self.tail.link=t
    self.tail=t
    return true
  end
  function object:push(str)
    if self.len>=self.size then
      self:del()
    end
    self:put(str)
  end
  function object:get()
    if self.head then
      local t=self.head
      self.len=self.len-1
      if t.link then
        self.head=t.link
      else
        self.head=nil
        self.tail=nil
        self.len=0
      end
      return t.val
    end
    return nil
  end
  function object:del()
    if self.head then
      local t=self.head
      self.len=self.len-1
      if t.link then
        self.head=t.link
      else
        self.head=nil
        self.tail=nil
        self.len=0
      end
    end
  end
  function object:iter()
    local i=self.head
    return function()
      if i then
        local v=i.val
        i=i.link
        return v
      end
      return nil
    end
  end
  function object:ited()
    local q=self
    local i=self.head
    return function()
      if i then
        local v=i.val
        i=i.link
        q.head=i
        q.len=q.len-1
        return v
      end
      q.head=nil
      q.tail=nil
      q.len=0
      return nil
    end
  end
  function object:itfx()
    if not self.head then
      self.tail=nil
      self.tail=nil
      self.len=0
    end
  end
  function object:clear()
    self.head=nil
    self.tail=nil
    self.len=0
  end
  return object
end

function squeue(sz)
  local object={}
  object.size=sz or 100
  object.len=0
  object.seq=0
  function object:put(str)
    if self.len>=self.size then
      return nil
    end
    local t={}
    self.len=self.len+1
    self.seq=self.seq+1
    t.val=self.seq.."!"..str
    t.seq=self.seq
    if not self.tail then
      self.head=t
      self.tail=t
      return false
    end
    self.tail.link=t
    self.tail=t
    return true
  end
  function object:get(ts,dt)
    local i=self.head
    while i do
      if (not i.ts) or ts>=i.ts then
        i.ts=ts+dt
        return i.val
      end
      i=i.link
    end
    return nil
  end
  function object:del(seq)
    local l=self.head
    local p=nil
    while l and l.seq<seq do
      p=l
      l=l.link
    end
    if not l then
      return
    end
    if l.seq>seq then
      return
    end
    self.len=self.len-1
    if not p then
      self.head=l.link
      if not l.link then
        self.tail=nil
      end
      return
    end
    if not l.link then
      p.link=nil
      self.tail=p
    else
      p.link=l.link
    end
  end
  function object:iter(_ts,_dt)
    local i=self.head
    local ts=_ts
    local dt=_dt
    return function()
      while i do
        if (not i.ts) or ts>=i.ts then
          local v=i.val
          i.ts=ts+dt
          i=i.link
          return v
        end
        i=i.link
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

function rqueue(sz)
  local object={}
  object.size=sz or 100
  object.len=0
  object.seq=0
  function object:put(str)
    if self.len>=self.size then
      return nil
    end
    local p=str:find("!",1,true)
    if not p then
      return nil
    end
    local seq=tonumber(str:sub(1,p-1))
    if seq<=self.seq then
      return seq
    end
    local msg=str:sub(p+1,str:len())
    if not self.head then
      local t={seq=seq,val=msg}
      self.head=t
      self.tail=t
      self.len=self.len+1
      return seq
    end
    local l=self.head
    local p=nil
    while l and l.seq<seq do
      p=l
      l=l.link
    end
    if not l then
      local t={seq=seq,val=msg}
      self.tail.link=t
      self.tail=t
      self.len=self.len+1
      return seq
    end
    if seq==l.seq then
      return seq
    end
    if not p then
      local t={seq=seq,val=msg}
      t.link=self.head
      self.head=t
      self.len=self.len+1
      return seq
    end
    local t={seq=seq,val=msg}
    p.link=t
    t.link=l
    self.len=self.len+1
    return seq
  end
  function object:get(seq)
    if self.head then
      local t=self.head
      if t.seq~=seq then
        return nil
      end
      self.len=self.len-1
      self.seq=t.seq
      if t.link then
        self.head=t.link
      else
        self.head=nil
        self.tail=nil
        self.len=0
      end
      return t.val
    end
    return nil
  end
  function object:del(seq)
    if self.head then
      local t=self.head
      if t.seq~=seq then
        return nil
      end
      self.len=self.len-1
      self.seq=t.seq
      if t.link then
        self.head=t.link
      else
        self.head=nil
        self.tail=nil
        self.len=0
      end
    end
  end
  function object:clear()
    local i=self.head
    local s=self.seq
    while i do
      s=i.seq
      i=i.link
    end
    self.seq=s
    self.head=nil
    self.tail=nil
    self.len=0
  end
  return object
end
