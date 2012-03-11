-- vim:et

require "socket"

local sock=socket:tcp()
local allsocks={sock}
local insync=false

function net_conn(addr,port)
  if sock:connect("127.0.0.1",6352) then
    while not insync do
      net_read()
    end
    return true
  end
  return false
end

function net_send(fmt,...)
  local str=string.format(fmt,unpack(arg))
  sock:send(str)
end

function net_close()
  sock:close()
end

function net_read()
  local str=sock:receive()
  if not str then
    love.event.push("q")
    insync=true
    return
  end
  local a=str_split(str,":")
  if a.n==1 then
    if a[1]=="DONE" then
      insync=true
    end
    return
  end
  if a[1]=="Pe" then -- Emit:idx:dev1:dev2:val
    if a.n<5 then
      return
    end
    local idx=tonumber(a[2])
    local d1=devices[tonumber(a[3])]
    local d2=devices[tonumber(a[4])]
    local v=tonumber(a[5])
    local p=Packet:new(d1,d2,v)
    p.idx=idx
    packets[idx]=p
    return
  end
  if a[1]=="Pd" then -- Discard:idx
    if a.n<1 then
      return
    end
    local idx=tonumber(a[2])
    local p=packets[idx]
    p:dequeue()
    packets[idx]=nil
    return
  end
  if a[1]=="Pr" then -- Route:idx:dev1:dev2
    if a.n<3 then
      return
    end
    local idx=tonumber(a[2])
    local d1=devices[tonumber(a[3])]
    local d2=devices[tonumber(a[4])]
    local p=packets[idx]
    p:dequeue()
    p:route(d1,d2)
    return
  end
  if a[1]=="Ph" then -- Heal:idx:dev:health
    if a.n<4 then
      return
    end
    local idx=tonumber(a[2])
    local o=devices[tonumber(a[3])]
    local p=packets[idx]
    o.health=tonumber(a[4])
    p:dequeue()
    packets[idx]=nil
    return
  end
  if a[1]=="PLa" then -- PLa:idx:cash
    if a.n<3 then
      return
    end
    local idx=tonumber(a[2])
    local cash=tonumber(a[3])
    local pl=Player:new(cash)
    pl.idx=idx
    players[idx]=pl
    if a[4]=="me" then
      ME=pl
    end
    return
  end
  if a[1]=="PLd" then -- PLa:idx
    if a.n<2 then
      return
    end
    local idx=tonumber(a[2])
    local pl=players[idx]
    pl:disconnect()
    players[idx]=nil
    return
  end
  if a[1]=="PLc" then -- PLc:idx:cash
    if a.n<3 then
      return
    end
    local pl=players[tonumber(a[2])]
    local cash=tonumber(a[3])
    pl.cash=cash
    return
  end
  if a[1]=="Da" then -- Add:pl:cl:idx:online:x:y
    if a.n<7 then
      return
    end
    local pl=players[tonumber(a[2])]
    local cl=devcl[a[3]]
    local idx=tonumber(a[4])
    local b=tonumber(a[5])==1 and true or false
    if not cl then
      return
    end
    local x,y=tonumber(a[6]),tonumber(a[7])
    local o=cl:new(pl,x,y)
    o.idx=idx
    o:init_gui()
    o.online=b
    devices[idx]=o
    return
  end
  if a[1]=="Dn" then -- New:pl:cl:idx:x:y
    if a.n<6 then
      return
    end
    local pl=players[tonumber(a[2])]
    local cl=devcl[a[3]]
    local idx=tonumber(a[4])
    if not cl then
      return
    end
    local x,y=tonumber(a[5]),tonumber(a[6])
    local o=cl:new(pl,x,y)
    o.idx=idx
    o:init_gui()
    devices[idx]=o
    return
  end
  if a[1]=="Dm" then -- Move:idx:x,y
    if a.n<4 then
      return
    end
    local idx=tonumber(a[2])
    local x,y=tonumber(a[3]),tonumber(a[4])
    local o=devices[idx]
    o:move(x,y)
    return
  end
  if a[1]=="Ds" then -- Switch:idx:online
    if a.n<3 then
      return
    end
    local idx=tonumber(a[2])
    local b=tonumber(a[3])==1 and true or false
    local o=devices[idx]
    o:switch(b)
    return
  end
  if a[1]=="L" then -- Link:idx:dev1:dev2
    if a.n<3 then
      return
    end
    local idx=tonumber(a[2])
    local d1=devices[tonumber(a[3])]
    local d2=devices[tonumber(a[4])]
    local l=d1:connect(d2)
    l.idx=idx
    links[idx]=l
    return
  end
end

function net_proc()
  ret=socket.select(allsocks,nil,0)
  if ret[sock] then
    net_read()
  end
end
