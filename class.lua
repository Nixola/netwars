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

class "List"

function List:add(o)
  local t={}
  o.__link=t
  t._obj=o
  if not self._tail then
    self._head=t
    self._tail=t
    t._prev=nil
    t._next=nil
    return
  end
  t._next=nil
  t._prev=self._tail
  self._tail._next=t
  self._tail=t
end

function List:del(o)
  local t=o.__link
  o.__link=nil
  t._obj=nil
  if self._tail==t then
    if self._head==t then
      self._head=nil
      self._tail=nil
      return
    end
    t=self._tail._prev
    t._next=nil
    self._tail=t
    return
  end
  if t._prev then
    t._prev._next=t._next
  end
  if t._next then
    t._next._prev=t._prev
  end
end

function List:count()
  local i=self._head
  local cnt=0
  while i do
    cnt=cnt+1
    i=i._next
  end
  return cnt
end

function List:iter()
  local i=self._head
  local o
  return function ()
    if i then
      o=i._obj
      i=i._next
      return o
    end
    return nil
  end
end

function List:find(o)
  local i=self._head
  while i do
    if o==i._obj then
      return o
    end
    i=i._next
  end
  return nil
end
