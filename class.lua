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

local mt_table={}
function mt_table:add(o)
  local idx=#self+1
  o.__idx=idx
  self[idx]=o
  return idx
end
function mt_table:del(o)
  local idx=o.__idx
  o.__idx=nil
  self[idx]=nil
  return idx
end
function mt_table:find(o)
  local idx=o.__idx
  if self[idx]==o then
    return idx
  end
  return nil
end
function ctable()
  local t={}
  setmetatable(t,{__index=mt_table})
  return t
end

function str_split(str,sep)
  local a={}
  local l=#str
  local p=1,q
  q=string.find(str,sep,1,true)
  while q do
    a[#a+1]=string.sub(str,p,q-1)
    p=q+1
    q=string.find(str,sep,p,true)
  end
  a[#a+1]=string.sub(str,p,l)
  a.n=#a
  return a
end
