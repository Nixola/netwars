-- vim:et

require "class"

local function spkeys(grid,x1,y1,x2,y2)
  local sx=math.floor(x1/grid)
  local sy=math.floor(y1/grid)
  local mx=math.floor(x2/grid)
  local my=math.floor(y2/grid)
  local x,y
  if mx<sx then
    x=mx
    mx=sx
    sx=x
  else
    x=sx
  end
  if my<sy then
    y=my
    my=sy
    sy=y
  else
    y=sy
  end
  return function()
    if y>my then
      return nil
    end
    local k=x..","..y
    x=x+1
    if x>mx then
      x=sx
      y=y+1
    end
    return k
  end
end

function sphash(grid)
  local object={}
  object.grid=grid or 100
  object.hash={}
  function object:add(dev)
    local t
    for k in spkeys(self.grid,dev:bound_box()) do
      t=self.hash[k]
      if not t then
        t=storage()
        self.hash[k]=t
      end
      t:add(dev)
    end
  end
  function object:del(dev)
    local t
    for k in spkeys(self.grid,dev:bound_box()) do
      t=self.hash[k]
      if t then
        t:del(dev)
      end
    end
  end
  function object:get(x1,y1,x2,y2)
    local grid=self.grid
    local sx=math.floor(x1/grid)
    local sy=math.floor(y1/grid)
    local mx=x2 and math.floor(x2/grid) or sx
    local my=y2 and math.floor(y2/grid) or sy
    local x,y
    if mx<sx then
      x=mx
      mx=sx
      sx=x
    else
      x=sx
    end
    if my<sy then
      y=my
      my=sy
      sy=y
    else
      y=sy
    end
    local ret={}
    local k,t,v
    while y<=my do
      k=x..","..y
      t=self.hash[k]
      if t then
        for _,v in pairs(t) do
          ret[v]=v
        end
      end
      x=x+1
      if x>mx then
        x=sx
        y=y+1
      end
    end
    return ret
  end
  return object
end
