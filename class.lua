-- vim:et

abs=math.abs
min=math.min
max=math.max
random=math.random
floor=math.floor
ceil=math.ceil
sqrt=math.sqrt
sin=math.sin
cos=math.cos
tan=math.tan

function count(t)
  local c=0
  for _ in pairs(t) do
    c=c+1
  end
  return c
end

function icopy(t)
  local tmp={}
  for i,v in ipairs(t) do
    tmp[i]=v
  end
  return tmp
end

local reserved={
class=true;
define=true;
extends=true;
new=true;
super=true;
__class=true;
__super=true;
__suptab=true;
}

local classes={}

function class(name)
  local newclass={}
  _G[name]=newclass
  classes[newclass]=true
  newclass.class=name
  function newclass.define(class,members)
    for k,v in pairs(members) do
      class[k]=v
    end
  end
  function newclass.extends(class,base)
    class.__super=base
    for k,v in pairs(base) do
      if not reserved[k] and not class[k] and type(v)~="function" then
        class[k]=v
      end
    end
    return class
  end
  local function init_class(class)
    local cl=class
    while cl do
      if classes[cl] then
        local ftab={}
        for k,v in pairs(cl) do
          if type(v)=="function" then
            ftab[k]=true
          end
        end
        local suptab={}
        local supcl=cl.__super
        while supcl do
          for k,v in pairs(supcl) do
            if type(v)=="function" and not reserved[k] and not suptab[k] then
              if ftab[k] then
                suptab[k]={func=v,super=supcl.__super}
              else
                ftab[k]=true
              end
            end
          end
          supcl=supcl.__super
        end
        cl.__suptab=suptab
        classes[cl]=false
      end
      cl=cl.__super
    end
  end
  function newclass.new(class,...)
    if class.__class then
      return class.__class:new(...)
    end
    if classes[class] then
      init_class(class)
    end
    local object={}
    object.__class=class
    object.class=class.class
    object.super=class.super
    object.__super=class
    for k,v in pairs(class) do
      if not reserved[k] then
        object[k]=v
      end
    end
    local supcl=class.__super
    while supcl do
      for k,v in pairs(supcl) do
        if not object[k] and not reserved[k] and type(v)=="function" then
          object[k]=v
        end
      end
      supcl=supcl.__super
    end
    if object.initialize then
      object:initialize(...)
    end
    return object
  end
  function newclass.super(class,func,...)
    local super=class.__super or class.__class
    local suptab=super.__suptab
    local chunk=suptab[func].func
    class.__super=suptab[func].super
    local ret=chunk(class,...)
    class.__super=super
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
      if not i.ts or ts>=i.ts then
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
        if not i.ts or ts>=i.ts then
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
    if not seq then
      return nil
    end
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

function runqueue()
  local object={}
  object.len=0
  object.hash={}
  function object:put(o,ts,dt)
    if self.hash[o] then
      return
    end
    local t={}
    t.val=o
    t.tm=ts
    t.ts=ts+dt
    self.len=self.len+1
    self.hash[o]=true
    if not self.tail then
      self.head=t
      self.tail=t
      return
    end
    local p=self.head
    local l=nil
    while p and p.ts<t.ts do
      l=p
      p=p.link
    end
    if not p then
      self.tail.link=t
      self.tail=t
      return
    end
    if not l then
      t.link=p
      self.head=t
      return
    end
    l.link=t
    t.link=p
  end
  function object:add(o,ts,dt)
    if self.hash[o] then
      return
    end
    local t={}
    t.val=o
    t.tm=ts
    t.ts=ts+dt
    self.len=self.len+1
    self.hash[o]=true
    if not self.tail then
      self.head=t
      self.tail=t
    else
      self.tail.link=t
      self.tail=t
    end
  end
  function object:del()
    if not self.last then
      return
    end
    local o=self.tail.val
    if self.last==self.tail then
      self.head=nil
      self.tail=nil
    else
      self.last.link=nil
      self.tail=self.last
    end
    self.len=self.len-1
    self.hash[o]=nil
    self.last=nil
  end
  function object:clear()
    self.len=0
    self.hash={}
    self.last=nil
    self.head=nil
    self.tail=nil
  end
  function object:iter(_ts,_dt)
    local p=self.head
    local c=1
    local ts=_ts
    local dt=_dt
    return function()
      self.last=nil
      if not p or c>self.len or ts<p.ts then
        return nil
      end
      local v=p.val
      local d=ts-p.tm
      p.tm=ts
      p.ts=ts+dt-(ts-p.ts)
      self.last=self.tail
      c=c+1
      if p==self.tail then
        p=nil
        return v,d
      end
      self.tail.link=p
      self.tail=p
      p=p.link
      self.tail.link=nil
      self.head=p
      if not self.head then
        self.head=self.tail
      end
      return v,d
    end
  end
  return object
end
