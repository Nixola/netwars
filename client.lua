-- vim:et

require "socket"

local sock=socket:udp()
local allsocks={sock}
local insync=false

function net_conn(addr,port)
  if sock:setpeername("127.0.0.1",6352) then
    sock:settimeout(5.0)
    sock:send("PLr")
    while not insync do
      net_read()
    end
    sock:settimeout()
    return true
  end
  return false
end

function net_send(fmt,...)
  local str=string.format(fmt,unpack(arg))
  sock:send(str)
end

function net_close()
  sock:send("PLu")
  sock:close()
end

local function parse_server(msg)
  a=str_split(msg,":")
  if a.n==1 then
    if a[1]=="DONE" then
      insync=true
    end
    return
  end
  if a[1]=="Pr" then -- Routed:dev1:dev2:val:val
    if a.n<5 then
      return
    end
    local d1=devices[tonumber(a[2])]
    local d2=devices[tonumber(a[3])]
    local v=tonumber(a[4])
    d1.pkt=tonumber(a[5])
    local p=Packet:new(d1,d2,v)
    packets:add(p)
    return
  end
  if a[1]=="Pe" then -- Emit:dev1:dev2:val
    if a.n<4 then
      return
    end
    local d1=devices[tonumber(a[2])]
    local d2=devices[tonumber(a[3])]
    local p=Packet:new(d1,d2,tonumber(a[4]))
    packets:add(p)
    return
  end
  if a[1]=="Pc" then -- Cash:idx:cash
    if a.n<3 then
      return
    end
    local pl=players[tonumber(a[2])]
    pl.cash=tonumber(a[3])
    return
  end
  if a[1]=="Ph" then -- Hit:dev:health
    if a.n<3 then
      return
    end
    local o=devices[tonumber(a[2])]
    o.health=tonumber(a[3])
    return
  end
  if a[1]=="Da" then -- Add:pl:cl:idx:online:x:y
    if a.n<7 then
      return
    end
    local pl=players[tonumber(a[2])]
    local cl=devcl[a[3]]
    local idx=tonumber(a[4])
    local b=tonumber(a[5])==1
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
    if pl==ME then
      mydevs[idx]=o
    end
    return
  end
  if a[1]=="Dd" then -- Del:idx
    if a.n<2 then
      return
    end
    local idx=tonumber(a[2])
    local o=devices[idx]
    o:delete()
    devices[idx]=nil
    if o.pl==ME then
      mydevs[idx]=nil
    end
    return
  end
  if a[1]=="Dm" then -- Move:idx:x,y
    if a.n<4 then
      return
    end
    local o=devices[tonumber(a[2])]
    local x,y=tonumber(a[3]),tonumber(a[4])
    o:move(x,y)
    return
  end
  if a[1]=="Ds" then -- Switch:idx:online
    if a.n<3 then
      return
    end
    local o=devices[tonumber(a[2])]
    local b=tonumber(a[3])==1
    o:switch(b)
    return
  end
  if a[1]=="La" then -- Link:dev1:dev2
    if a.n<3 then
      return
    end
    local d1=devices[tonumber(a[2])]
    local d2=devices[tonumber(a[3])]
    local l=d1:connect(d2)
    if l then
      links:add(l)
    end
    return
  end
  if a[1]=="Lu" then -- Link:dev1:dev2
    if a.n<3 then
      return
    end
    local d1=devices[tonumber(a[2])]
    local d2=devices[tonumber(a[3])]
    local l=d1:unlink(d2)
    if l then
      l:del_packets()
      links:del(l)
    end
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
end

function net_read()
  local p=sock:receive()
  if not p then
    love.event.push("q")
    insync=true
    return
  end
  local mt=str_split(p,"|")
  for i,m in ipairs(mt) do
    parse_server(m)
  end
end

function net_proc()
  ret=socket.select(allsocks,nil,0)
  if ret[sock] then
    net_read()
  end
end
