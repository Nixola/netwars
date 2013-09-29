-- vim:et

local function spkeys(grid,x1,y1,x2,y2)
  local sx,sy
  local mx,my
  if not x2 then
    sx=math.floor(x1/grid)
    mx=sx
  elseif x1<x2 then
    sx=math.floor(x1/grid)
    mx=math.ceil(x2/grid)
  else
    sx=math.floor(x2/grid)
    mx=math.ceil(x1/grid)
  end
  if not y2 then
    sy=math.floor(y1/grid)
    my=sy
  elseif y1<y2 then
    sy=math.floor(y1/grid)
    my=math.ceil(y2/grid)
  else
    sy=math.floor(y2/grid)
    my=math.ceil(y1/grid)
  end
  local x,y=sx,sy
  return function()
    if y>my then
      return nil
    end
    local k=string.format("%d,%d",x,y)
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
  function object:add(o)
    local t
    for k in spkeys(self.grid,o:bound_box()) do
      t=self.hash[k]
      if not t then
        t={}
        self.hash[k]=t
      end
      t[o]=o
    end
  end
  function object:del(o)
    local t
    for k in spkeys(self.grid,o:bound_box()) do
      t=self.hash[k]
      if t then
        t[o]=nil
      end
    end
  end
  function object:get(x1,y1,x2,y2)
    local ret={}
    local t
    for k in spkeys(self.grid,x1,y1,x2,y2) do
      t=self.hash[k]
      if t then
        for _,o in pairs(t) do
          ret[o]=o
        end
      end
    end
    return ret
  end
  return object
end
