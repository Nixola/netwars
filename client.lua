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
    love.event.push("q")
    return
  end
  net_parse(msg)
  return insync
end

function net_send(fmt,...)
  sendq:put(string.format(fmt,...))
end

function net_close()
  sock:send("DISCONNECT")
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
  if a[1]=="Pi" then -- Info:dev:val
    if a.n<3 then
      return
    end
    local o=devices[tonumber(a[2])]
    if o then
      o.pkt=tonumber(a[3])
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
  if a[1]=="Pc" then -- Cash:idx:cash:maxcash
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
  if a[1]=="Da" then -- Add:pl:cl:idx:health:online:x:y:...
    if a.n<8 then
      return
    end
    local pl=players[tonumber(a[2])]
    local cl=devcl[a[3]]
    local idx=tonumber(a[4])
    local b=tonumber(a[6])==1
    local x,y=tonumber(a[7]),tonumber(a[8])
    if not cl then
      return
    end
    local o=cl:new(pl,x,y)
    if a[3]=="G" or a[3]=="B" then
      if a.n<9 then
        return
      end
      o.pwr=tonumber(a[9])
    end
    o.idx=idx
    o.health=tonumber(a[5])
    o:init_gui()
    o.online=b
    devices[idx]=o
    devhash:add(o)
    return
  end
  if a[1]=="Dn" then -- New:pl:cl:idx:x:y:...
    if a.n<6 then
      return
    end
    local pl=players[tonumber(a[2])]
    local cl=devcl[a[3]]
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
    devhash:add(o)
    return
  end
  if a[1]=="Do" then -- Del:idx:pl:health
    if a.n<4 then
      return
    end
    local idx=tonumber(a[2])
    local o=devices[idx]
    o:del_packets()
    o:del_links()
    o.pl=players[tonumber(a[3])]
    o.health=tonumber(a[4])
    o.online=false
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
  if a[1]=="MSG" then -- MSG:nick:~msg
    if a.n<3 then
      return
    end
    if chat.chatq.len>=chat.chatq.size then
      chat.chatq:del()
    end
    chat.chatq:put(string.format("<%s> %s",a[2],a[3]))
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

function net_parse(msg)
  local p=recvq:get(seq)
  local mt
  if p then
    seq=seq+1
    mt=str_split(p,"|")
    for _,m in ipairs(mt) do
      parse_server(m)
    end
  end
  if msg then
    mt=str_split(msg,"|")
    for _,m in ipairs(mt) do
      parse_server(m)
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
  net_parse(msg)
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
