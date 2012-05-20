-- vim:et

require "socket"

local sock
local sendq=squeue()
local recvq=rqueue()
local seq=0
local allsocks
local insync=false
local timeout=0

function net_conn(addr,nick)
  sock=socket.udp()
  allsocks={sock}
  local ts=socket.gettime()
  timeout=ts+5
  seq=1
  sock:setpeername(addr,6352)
  sock:send(string.format("PLr:%s:%d",nick,NVER))
end

function net_sync()
  if net_err then
    return false
  end
  if timeout==0 then
    return false
  end
  local ts=socket.gettime()
  local ret=socket.select(allsocks,nil,0)
  local msg
  if ret[sock] then
    msg=net_read(ts)
  end
  if ts>=timeout then
    net_err="timeout..."
    return true
  end
  net_parse(msg,ts)
  return insync
end

function net_send(fmt,...)
  sendq:put(string.format(fmt,...))
end

function net_close()
  sock:send("DISCONNECT")
  sock:close()
end

local function parse_server(msg,ts)
  local a=str_split(msg,":")
  if a[1]=="ACK" then
    if a.n==2 then
      sendq:del(tonumber(a[2]))
    end
    return
  end
  if a[1]=="PING" then
    if a.n<3 then
      return
    end
    sock:send(string.format("PONG:%s",a[2]))
    srvts=tonumber(a[2])+tonumber(a[3])
    lastsend=ts+5
    return
  end
  if a[1]=="Pr" then -- Routed:d1:d2:pkt:pkt
    if a.n<5 then
      return
    end
    local d1=devices[tonumber(a[2])]
    local d2=devices[tonumber(a[3])]
    local pkt1=tonumber(a[4])
    local pkt2=tonumber(a[5])
    if d1 and d2 then
      d1.pkt=pkt1 or 0
      d2.pkt=pkt2
      local p=Packet:new(d1,d2)
      packets:add(p)
    end
    return
  end
  if a[1]=="Pc" then -- Cash:d1:d2:cash:pkt
    if a.n<5 then
      return
    end
    local d1=devices[tonumber(a[2])]
    local d2=devices[tonumber(a[3])]
    local pl=d2 and d2.pl or nil
    if pl then
      pl.cash=tonumber(a[4])
      d1.pkt=tonumber(a[5])
      local p=Packet:new(d1,d2)
      packets:add(p)
    end
    return
  end
  if a[1]=="Um" then -- Move:idx:ts:x:y:x:y
    if a.n<7 then
      return
    end
    local o=units[tonumber(a[2])]
    local ts=tonumber(a[3])
    local x,y=tonumber(a[6]),tonumber(a[7])
    uhash:del(o)
    o.x=tonumber(a[4])
    o.y=tonumber(a[5])
    o:move(x,y)
    o:_step(srvts-ts)
    uhash:add(o)
    return
  end
  if a[1]=="Up" then -- Move:idx:x,y
    if a.n<4 then
      return
    end
    local o=units[tonumber(a[2])]
    local x,y=tonumber(a[3]),tonumber(a[4])
    uhash:del(o)
    o.x=tonumber(a[3])
    o.y=tonumber(a[4])
    uhash:add(o)
    o.vx=nil
    o.vy=nil
    return
  end
  if a[1]=="Sp" then -- Hit:u1:u2:pkt:pkt
    if a.n<5 then
      return
    end
    local u1=units[tonumber(a[2])]
    local u2=units[tonumber(a[3])]
    if u1 and u2 then
      u1.pkt=tonumber(a[4])
      u2.pkt=tonumber(a[5])
      local s=Shot:new(u1,u2)
      shots:add(s)
    end
    return
  end
  if a[1]=="SP" then -- Hit:d1:u2:pkt:pkt
    if a.n<5 then
      return
    end
    local d1=devices[tonumber(a[2])]
    local u2=units[tonumber(a[3])]
    if d1 and u2 then
      d1.pkt=tonumber(a[4])
      u2.pkt=tonumber(a[5])
      local s=Shot:new(d1,u2)
      shots:add(s)
    end
    return
  end
  if a[1]=="Sh" then -- Hit:u1:u2:pkt:health
    if a.n<5 then
      return
    end
    local u1=units[tonumber(a[2])]
    local u2=units[tonumber(a[3])]
    if u1 and u2 then
      u1.pkt=tonumber(a[4])
      u2.health=tonumber(a[5])
      local s=Shot:new(u1,u2)
      shots:add(s)
    end
    return
  end
  if a[1]=="SH" then -- Hit:u1:d2:pkt:health
    if a.n<5 then
      return
    end
    local u1=units[tonumber(a[2])]
    local d2=devices[tonumber(a[3])]
    if u1 and d2 then
      u1.pkt=tonumber(a[4])
      d2.health=tonumber(a[5])
      local s=Shot:new(u1,d2)
      shots:add(s)
    end
    return
  end
  if a[1]=="SC" then -- Capture:u1:d2:pkt
    if a.n<4 then
      return
    end
    local u1=units[tonumber(a[2])]
    local d2=devices[tonumber(a[3])]
    if u1 and d2 then
      u1.pkt=tonumber(a[4])
      local s=Shot:new(u1,d2)
      shots:add(s)
    end
    return
  end
  if a[1]=="SO" then -- Takeover:u1:d2:pkt
    if a.n<4 then
      return
    end
    local u1=units[tonumber(a[2])]
    local d2=devices[tonumber(a[3])]
    local pl=u1.pl
    u1.pkt=tonumber(a[4])
    d2:takeover(pl)
    u1.targ=nil
    local s=Shot:new(u1,d2)
    shots:add(s)
    return
  end
  if a[1]=="Sd" then -- Destroy:u1:u2:pkt
    if a.n<4 then
      return
    end
    local idx=tonumber(a[3])
    local u1=units[tonumber(a[2])]
    local u2=units[idx]
    u1.pkt=tonumber(a[4])
    u2:delete()
    units[idx]=nil
    local s=Shot:new(u1,u2)
    shots:add(s)
    return
  end
  if a[1]=="SD" then -- Destroy:u1:d2:pkt
    if a.n<4 then
      return
    end
    local idx=tonumber(a[3])
    local u1=units[tonumber(a[2])]
    local d2=devices[idx]
    u1.pkt=tonumber(a[4])
    d2:delete()
    devices[idx]=nil
    local s=Shot:new(u1,d2)
    shots:add(s)
    return
  end
  if a[1]=="Th" then -- Hit:d1:u2:pkt:health
    if a.n<5 then
      return
    end
    local d1=devices[tonumber(a[2])]
    local u2=units[tonumber(a[3])]
    if d1 and u2 then
      d1.pkt=tonumber(a[4])
      u2.health=tonumber(a[5])
      local s=Shot:new(d1,u2)
      shots:add(s)
    end
    return
  end
  if a[1]=="Td" then -- Destroy:d1:u2:pkt
    if a.n<4 then
      return
    end
    local idx=tonumber(a[3])
    local d1=devices[tonumber(a[2])]
    local u2=units[idx]
    d1.pkt=tonumber(a[4])
    u2:delete()
    units[idx]=nil
    local s=Shot:new(d1,u2)
    shots:add(s)
    return
  end
  if a[1]=="TH" then -- Hit:d1:d2:pkt:health
    if a.n<5 then
      return
    end
    local d1=devices[tonumber(a[2])]
    local d2=devices[tonumber(a[3])]
    if d1 and d2 then
      d1.pkt=tonumber(a[4])
      d2.health=tonumber(a[5])
      local s=Shot:new(d1,d2)
      shots:add(s)
    end
    return
  end
  if a[1]=="TD" then -- Destroy:d1:d2:pkt
    if a.n<4 then
      return
    end
    local idx=tonumber(a[3])
    local d1=devices[tonumber(a[2])]
    local d2=devices[idx]
    d1.pkt=tonumber(a[4])
    d2:delete()
    devices[idx]=nil
    local s=Shot:new(d1,d2)
    shots:add(s)
    return
  end
  if a[1]=="Dn" then -- New:pl:cl:idx:x:y:...
    if a.n<6 then
      return
    end
    local pl=players[tonumber(a[2])]
    local cl=d_cl[a[3]]
    local idx=tonumber(a[4])
    local x,y=tonumber(a[5]),tonumber(a[6])
    if not cl then
      return
    end
    local o=cl:new(pl,x,y)
    if a[3]=="G" or a[3]=="B" then
      if a.n<7 then
        return
      end
      o.pwr=tonumber(a[7])
    end
    o.idx=idx
    o:init_gui()
    devices[idx]=o
    dhash:add(o)
    return
  end
  if a[1]=="Un" then -- New:pl:cl:idx:x:y:...
    if a.n<6 then
      return
    end
    local pl=players[tonumber(a[2])]
    local cl=u_cl[a[3]]
    local idx=tonumber(a[4])
    local x,y=tonumber(a[5]),tonumber(a[6])
    if not cl then
      return
    end
    local o=cl:new(pl,x,y)
    o.idx=idx
    units[idx]=o
    uhash:add(o)
    if o.cl=="c" then
      pl.havecmd=true
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
  if a[1]=="Du" then -- Upgrade:idx:v
    if a.n<3 then
      return
    end
    local o=devices[tonumber(a[2])]
    o.ec=tonumber(a[3])
    return
  end
  if a[1]=="Lc" then -- Link:dev1:dev2
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
  if a[1]=="Lu" then -- Unlink:dev1:dev2
    if a.n<3 then
      return
    end
    local d1=devices[tonumber(a[2])]
    local d2=devices[tonumber(a[3])]
    local l=d1:unlink(d2)
    if l then
      links:del(l)
    end
    return
  end
  if a[1]=="PC" then -- Cash:idx:cash:maxcash
    if a.n<4 then
      return
    end
    local pl=players[tonumber(a[2])]
    if pl then
      pl.cash=tonumber(a[3])
      pl.maxcash=tonumber(a[4])
    end
    return
  end
  if a[1]=="Da" then -- Add:pl:cl:idx:health:online:x:y:...
    if a.n<8 then
      return
    end
    local pl=players[tonumber(a[2])]
    local cl=d_cl[a[3]]
    local idx=tonumber(a[4])
    local b=tonumber(a[6])==1
    local x,y=tonumber(a[7]),tonumber(a[8])
    if not cl then
      return
    end
    local o=cl:new(pl,x,y)
    if a[3]=="G" then
      if a.n<9 then
        return
      end
      o.pwr=tonumber(a[9])
    elseif o.ec then
      if a.n<10 then
        return
      end
      o.pkt=tonumber(a[9])
      o.ec=tonumber(a[10])
    elseif o.maxpkt then
      if a.n<9 then
        return
      end
      o.pkt=tonumber(a[9])
    end
    o.idx=idx
    o.health=tonumber(a[5])
    o:init_gui()
    o.online=b
    devices[idx]=o
    dhash:add(o)
    return
  end
  if a[1]=="Ua" then -- Add:pl:cl:idx:health:pkt:x:y
    if a.n<8 then
      return
    end
    local pl=players[tonumber(a[2])]
    local cl=u_cl[a[3]]
    local idx=tonumber(a[4])
    local x,y=tonumber(a[7]),tonumber(a[8])
    if not cl then
      return
    end
    local o=cl:new(pl,x,y)
    o.idx=idx
    o.health=tonumber(a[5])
    o.pkt=tonumber(a[6])
    units[idx]=o
    uhash:add(o)
    return
  end
  if a[1]=="PLa" then -- PLa:idx:nick:cash
    if a.n<4 then
      return
    end
    local idx=tonumber(a[2])
    local cash=tonumber(a[4])
    local pl=Player:new(cash)
    pl.idx=idx
    pl.name=a[3]
    players[idx]=pl
    if a[5]=="me" then
      ME=pl
      srvts=tonumber(a[6])
    end
    if insync then
      chat.msg(string.format("%s has connected.",a[3]))
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
    chat.msg(string.format("%s disconnected.",pl.name))
    return
  end
  if a[1]=="MSG" then -- MSG:nick:~msg
    if a.n<3 then
      return
    end
    chat.msg(string.format("<%s> %s",a[2],a[3]))
    return
  end
  if a[1]=="ERR" then
    net_err=a[2]
    return
  end
  if a[1]=="DONE" then
    insync=true
    net_send("OK")
  end
end

function net_parse(msg,ts)
  local p=recvq:get(seq)
  local mt
  if p then
    seq=seq+1
    mt=str_split(p,"|")
    for _,m in ipairs(mt) do
      parse_server(m,ts)
    end
  end
  if msg then
    mt=str_split(msg,"|")
    for _,m in ipairs(mt) do
      parse_server(m,ts)
    end
  end
end

local lastsend=0
local lastrecv=0
function net_read(ts)
  local str=sock:receive()
  if not str then
    return
  end
  lastrecv=ts+4
  timeout=ts+30
  if str:find("!",1,true) then
    local s=recvq:put(str)
    if not s then
      love.event.push("q")
      insync=true
      return nil
    end
    sock:send(string.format("ACK:%d",s))
    return nil
  end
  return str
end

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
  net_parse(msg,ts)
  for p in sendq:iter(ts,0.5) do
    sock:send(p)
  end
  if sendq.len>0 then
    lastsend=ts+5
  end
  if ts>=lastsend then
    if ts>=lastrecv then
      sock:send("PING")
    else
      sock:send("KEEPALIVE")
    end
    lastsend=ts+5
  end
end
