-- vim:et

require "socket"

local sock=socket:udp()
local sendq=squeue()
local recvq=rqueue()
local seq=0
local allsocks={sock}
local insync=false
local timeout=0
local addr,port

function net_conn(_addr,_port)
  addr,port=_addr,_port
  local ts=socket:gettime()
  timeout=timeout+5
  sock:sendto("CONNECT",addr,port)
  local msg
  while not insync do
    msg=net_read(ts)
    net_parse(msg)
    ts=ts+1
  end
  timeout=socket:gettime()+30
end

function net_send(fmt,...)
  local str=string.format(fmt,unpack(arg))
  print("net_send: ",str)
  sendq:put(str)
end

function net_close()
  sock:sendto("DISCONNECT",addr,port)
  sock:close()
end

local function parse_server(msg)
  local a=str_split(msg,":")
  if a[1]=="ACK" then
    if a.n==2 then
      sendq:del(tonumber(a[2]))
    end
    return
  end
  if a[1]=="Pr" then -- Routed:dev1:dev2:val:val
    if a.n<5 then
      return
    end
    local d1=devices[tonumber(a[2])]
    local d2=devices[tonumber(a[3])]
    if d1 and d2 then
      d1.pkt=tonumber(a[5])
      local p=Packet:new(d1,d2,tonumber(a[4]))
      packets:add(p)
    end
    return
  end
  if a[1]=="Pe" then -- Emit:dev1:dev2:val
    if a.n<4 then
      return
    end
    local d1=devices[tonumber(a[2])]
    local d2=devices[tonumber(a[3])]
    if d1 and d2 then
      local p=Packet:new(d1,d2,tonumber(a[4]))
      packets:add(p)
    end
    return
  end
  if a[1]=="Pc" then -- Cash:idx:cash
    if a.n<3 then
      return
    end
    local pl=players[tonumber(a[2])]
    if pl then
      pl.cash=tonumber(a[3])
    end
    return
  end
  if a[1]=="Ph" then -- Hit:dev:health
    if a.n<3 then
      return
    end
    local o=devices[tonumber(a[2])]
    if o then
      o.health=tonumber(a[3])
    end
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
  if a[1]=="DONE" then
    insync=true
    net_send("OK")
  end
end

function net_parse(msg)
  local p=recvq:get(seq)
  local mt
  if p then
    mt=str_split(p,"|")
    for i,m in ipairs(mt) do
      parse_server(m)
    end
  end
  if msg then
    mt=str_split(msg,"|")
    for i,m in ipairs(mt) do
      parse_server(m)
    end
  end
end

function net_read(ts)
  local str=sock:receivefrom()
  if not str then
    love.event.push("q")
    insync=true
    return
  end
  timeout=ts+30
  if str:find("!",1,true) then
    local s=recvq:put(str)
    if not s then
      love.event.push("q")
      insync=true
      return nil
    end
    seq=seq+1
    sock:sendto(string.format("ACK:%d",s),addr,port)
    return nil
  end
  return str
end

local lastsend=0
function net_proc()
  local ts=socket.gettime()
  local ret=socket.select(allsocks,nil,0)
  local msg
  if ret[sock] then
    msg=net_read(ts)
  end
  if ts>=timeout then
    love.event.push("q")
    return
  end
  net_parse(msg)
  for p in sendq:iter(ts,0.5) do
    print("send: ",p)
    sock:sendto(p,addr,port)
  end
  if sendq.len>0 then
    print("sendq have packets")
    lastsend=ts+5
  end
  if ts>=lastsend then
    sock:sendto("PING",addr,port)
    lastsend=ts+5
  end
end
