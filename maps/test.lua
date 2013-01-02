-- vim:et

local pi2=math.pi*2

local function ring(x,y,r,m)
  local rx,ry
  for t=0,m-1 do
    rx=math.sin((t/m)*pi2)
    ry=math.cos((t/m)*pi2)
    add_G(x+r*rx,y+r*ry,math.random(10))
  end
end

local r=1200
local rx,ry
local m=6

return function()
  for t=0,m-1 do
    rx=math.sin((t/m)*pi2)
    ry=math.cos((t/m)*pi2)
    ring(r*rx,r*ry,400,6)
  end
end
