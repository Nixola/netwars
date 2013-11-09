-- vim:et

require "socket"

local sock
local sendq
local recvq
local seq=0
local allsocks
local insync=false
local timeout=0
love.filesystem.mkdir("replays")
local rep=love.filesystem.newFile("replays/lastreplay")

local function init_vars()
  ME=nil
  players=ctable()
  devices=ctable()
  units=ctable()
  links=storage()
  packets=storage()
  shots=storage()
  dhash=sphash(200)
  uhash=sphash(100)
  rq_um=runqueue()
end

function net_conn(addr,nick)
  net_err=nil
  sendq=squeue()
  recvq=rqueue()
  init_vars()
  sock=socket.udp()
  allsocks={sock}
  local ts=socket.gettime()
  timeout=ts+5
  seq=1
  insync=false
  if not sock:setpeername(addr,6352) then
    net_err="host not found"
    return
  end
  sock:send(string.format("PLr:%s:%s",nick,NVER))
  rep:open("w")
end

function net_abort()
  if sock then
    sock:close()
    sock=nil
  end
end

local lastsend=0
local lastrecv=0
function net_read(ts)
  local str=sock:receive()
  if not str then
    return nil
  end
  lastrecv=ts+4
  timeout=ts+30
  if str:find("!",1,true) then
    local s=recvq:put(str)
    if not s then
      console.msg("! malformed packet received")
      net_err="malformed packet received"
      return nil
    end
    sock:send(string.format("ACK:%d",s))
    str=str_split(str,"!")[2]
    rep:write(string.format("%s@%s\n",ts,str))
    return nil
  end
  rep:write(string.format("%s@%s\n",ts,str))
  return str
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
    return false
  end
  net_parse(msg,ts)
  return insync
end

function net_send(fmt,...)
  sendq:put(string.format(fmt,...))
end

function net_close()
  if not replay and sock then
    sock:send("DISCONNECT")
    sock:close()
    rep:close()
    sock=nil
  end
end

local cmd={}

cmd["ACK"]=function(a,ts)
  if a.n==2 then
    sendq:del(tonumber(a[2]))
  end
end

cmd["PING"]=function(a,ts)
  if a.n<2 then
    return
  end
  sock:send(string.format("PONG:%s",a[2]))
  lastsend=ts+5
end

cmd["PINGS"]=function(a,ts)
  if a.n<3 then
    return
  end
  local c=(a.n-1)/2
  local i,pl
  for x=1,c do
    i=x*2
    pl=players[tonumber(a[i])]
    if pl then
      pl.showping=a[i+1]
    end
  end
end

cmd["MSG"]=function(a,ts) -- MSG:nick:~msg
  if a.n<3 then
    return
  end
  console.msg(string.format("<%s> %s",a[2],a[3]))
end

cmd["INFO"]=function(a,ts) -- INFO:~msg
  if a.n<2 then
    return
  end
  console.msg(string.format("%s",a[2]))
end

cmd["ERR"]=function(a,ts)
  net_err=a[2]
end

cmd["DONE"]=function(a,ts)
  insync=true
  fakets=socket.gettime()
  net_send("OK")
end

cmd["ALLY"]=function(a,ts)
  if a.n<3 then
    return
  end
  local p1=players[tonumber(a[2])]
  local p2=players[tonumber(a[3])]
  local b=tonumber(a[4])==1
  if ME==p1 then
    ally[p2]=b
  end
  local str=b and "friend" or "enemy"
  console.msg(string.format("%s sets relation to %s: %s",p1.name,p2.name,str))
end

cmd["PLa"]=function(a,ts) -- PLa:idx:nick:cash
  if a.n<4 then
    return
  end
  local idx=tonumber(a[2])
  local cash=tonumber(a[4])
  local pl=Player:new(cash)
  pl.idx=idx
  pl.name=a[3]
  pl.ping=0
  pl.showping=0
  players[idx]=pl
  if a[5]=="me" then
    ME=pl
  end
  if insync or replay then
    console.msg(string.format("%s has connected.",a[3]))
  end
end

cmd["PLd"]=function(a,ts) -- PLa:idx
  if a.n<2 then
    return
  end
  local idx=tonumber(a[2])
  local pl=players[idx]
  pl:disconnect()
  players[idx]=nil
  ally[pl]=nil
  console.msg(string.format("%s disconnected.",pl.name))
end

cmd["PC"]=function(a,ts) -- Cash:idx:cash:maxcash
  if a.n<4 then
    return
  end
  local pl=players[tonumber(a[2])]
  if pl then
    pl.cash=tonumber(a[3])
    pl.maxcash=tonumber(a[4])
  end
end

cmd["Da"]=function(a,ts) -- Add:pl:cl:idx:health:online:x:y:...
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
  o.online=b
  devices[idx]=o
  dhash:add(o)
end

cmd["Dn"]=function(a,ts) -- New:pl:cl:idx:x:y:...
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
  if a[3]=="G" then
    if a.n<7 then
      return
    end
    o.pwr=tonumber(a[7])
  end
  o.idx=idx
  if pl==ME then
    o:init_gui()
  end
  devices[idx]=o
  dhash:add(o)
  if o.cl=="B" and pl==ME then
    main_started()
  end
end

cmd["Dm"]=function(a,ts) -- Move:idx:x,y
  if a.n<4 then
    return
  end
  local o=devices[tonumber(a[2])]
  local x,y=tonumber(a[3]),tonumber(a[4])
  o:move(x,y)
end

cmd["Ds"]=function(a,ts) -- Switch:idx:bool
  if a.n<3 then
    return
  end
  local o=devices[tonumber(a[2])]
  local b=tonumber(a[3])==1
  o:switch(b)
end

cmd["Du"]=function(a,ts) -- Upgrade:idx:v
  if a.n<3 then
    return
  end
  local o=devices[tonumber(a[2])]
  o.ec=tonumber(a[3])
end

cmd["Dd"]=function(a,ts) -- Del:idx
  if a.n<2 then
    return
  end
  local idx=tonumber(a[2])
  local o=devices[idx]
  o:delete()
  devices[idx]=nil
end

cmd["Th"]=function(a,ts) -- Hit:d1:u2:pkt:health
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
end

cmd["Td"]=function(a,ts) -- Destroy:d1:u2:pkt
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
end

cmd["TH"]=function(a,ts) -- Hit:d1:d2:pkt:health
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
end

cmd["TD"]=function(a,ts) -- Destroy:d1:d2:pkt
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
end

cmd["Lc"]=function(a,ts) -- Link:dev1:dev2
  if a.n<3 then
    return
  end
  local d1=devices[tonumber(a[2])]
  local d2=devices[tonumber(a[3])]
  d1:link(d2)
end

cmd["Lu"]=function(a,ts) -- Unlink:dev1:dev2
  if a.n<3 then
    return
  end
  local d1=devices[tonumber(a[2])]
  local d2=devices[tonumber(a[3])]
  local l=d1:unlink(d2)
  if l then
    links:del(l)
  end
end

cmd["LU"]=function(a,ts) -- UNLINK:dev1
  if a.n<2 then
    return
  end
  local o=devices[tonumber(a[2])]
  o:unlink_all()
end

cmd["Pr"]=function(a,ts) -- Routed:d1:d2:pkt:pkt
  if a.n<5 then
    return
  end
  local d1=devices[tonumber(a[2])]
  local d2=devices[tonumber(a[3])]
  if d1 and d2 then
    d1.pkt=tonumber(a[4]) or 0
    d2.pkt=tonumber(a[5])
    local p=Packet:new(d1,d2)
    packets:add(p)
  end
end

cmd["Ph"]=function(a,ts) -- Routed:d1:d2:pkt:health
  if a.n<5 then
    return
  end
  local d1=devices[tonumber(a[2])]
  local d2=devices[tonumber(a[3])]
  if d1 and d2 then
    d1.pkt=tonumber(a[4]) or 0
    d2.health=tonumber(a[5])
    local p=Packet:new(d1,d2)
    packets:add(p)
  end
end

cmd["Pc"]=function(a,ts) -- Cash:d1:d2:cash:pkt
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
end

cmd["Ua"]=function(a,ts) -- Add:pl:cl:idx:health:blocked:x:y:pkt:...
  if a.n<9 then
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
  if o.uc then
    if a.n<10 then
      return
    end
    o.uc=tonumber(a[10])
  end
  o.idx=idx
  o.health=tonumber(a[5])
  o.blocked=tonumber(a[6])==1
  o.pkt=tonumber(a[9])
  units[idx]=o
  uhash:add(o)
end

cmd["Un"]=function(a,ts) -- New:pl:cl:idx:x:y:...
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
  if pl==ME then
    o:init_gui()
  end
  units[idx]=o
  uhash:add(o)
end

cmd["Um"]=function(a,ts) -- Move:idx:ts:x:y:x:y
  if a.n<7 then
    return
  end
  local o=units[tonumber(a[2])]
  local dt=tonumber(a[3])
  local x,y=tonumber(a[6]),tonumber(a[7])
  uhash:del(o)
  o.x=tonumber(a[4])
  o.y=tonumber(a[5])
  uhash:add(o)
  o:move(x,y)
  rq_um:add(o,fakets,0.01)
  o:step(dt)
end

cmd["Up"]=function(a,ts) -- Move:idx:x,y
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
end

cmd["Uu"]=function(a,ts) -- Upgrade:idx:v
  if a.n<3 then
    return
  end
  local o=units[tonumber(a[2])]
  o.uc=tonumber(a[3])
end

cmd["Ps"]=function(a,ts) -- Support:d1:u2:pkt:pkt
  if a.n<5 then
    return
  end
  local d1=devices[tonumber(a[2])]
  local u2=units[tonumber(a[3])]
  if d1 and u2 then
    d1.pkt=tonumber(a[4]) or 0
    u2.pkt=tonumber(a[5])
    local p=Packet:new(d1,u2)
    packets:add(p)
  end
end

cmd["Pu"]=function(a,ts) -- Health:d1:u2:pkt:health
  if a.n<5 then
    return
  end
  local d1=devices[tonumber(a[2])]
  local u2=units[tonumber(a[3])]
  if d1 and u2 then
    d1.pkt=tonumber(a[4]) or 0
    u2.health=tonumber(a[5])
    local p=Packet:new(d1,u2)
    packets:add(p)
  end
end

cmd["Sh"]=function(a,ts) -- Hit:u1:u2:pkt:health
  if a.n<5 then
    return
  end
  local u1=units[tonumber(a[2])]
  local u2=units[tonumber(a[3])]
  if u1 and u2 then
    u1.blocked=false
    u1.pkt=tonumber(a[4])
    u2.health=tonumber(a[5])
    local s=Shot:new(u1,u2)
    shots:add(s)
  end
  return
end

cmd["SH"]=function(a,ts) -- Hit:u1:d2:pkt:health
  if a.n<5 then
    return
  end
  local u1=units[tonumber(a[2])]
  local d2=devices[tonumber(a[3])]
  if u1 and d2 then
    u1.blocked=false
    u1.pkt=tonumber(a[4])
    d2.health=tonumber(a[5])
    local s=Shot:new(u1,d2)
    shots:add(s)
  end
end

cmd["Sd"]=function(a,ts) -- Destroy:u1:u2:pkt
  if a.n<4 then
    return
  end
  local idx=tonumber(a[3])
  local u1=units[tonumber(a[2])]
  local u2=units[idx]
  u1.blocked=false
  u1.pkt=tonumber(a[4])
  u2:delete()
  units[idx]=nil
  local s=Shot:new(u1,u2)
  shots:add(s)
end

cmd["SD"]=function(a,ts) -- Destroy:u1:d2:pkt
  if a.n<4 then
    return
  end
  local idx=tonumber(a[3])
  local u1=units[tonumber(a[2])]
  local d2=devices[idx]
  u1.blocked=false
  u1.pkt=tonumber(a[4])
  d2:delete()
  devices[idx]=nil
  local s=Shot:new(u1,d2)
  shots:add(s)
end

cmd["Sb"]=function(a,ts) -- Blocked:idx:bool
  if a.n<3 then
    return
  end
  local o=units[tonumber(a[2])]
  local b=tonumber(a[3])==1
  o.blocked=b
end

local function parse_server(msg,ts)
  local a=str_split(msg,":")
  local chunk=cmd[a[1]]
  if chunk then
    chunk(a,ts)
  end
end

local dummy={
ACK=true;
PING=true;
ERR=true;
DONE=true;
}

local function parse_replay(msg)
  local a=str_split(msg,":")
  if dummy[a[1]] then
    return
  end
  local chunk=cmd[a[1]]
  if chunk then
    chunk(a,0)
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

function rep_parse(msg)
  mt=str_split(msg,"|")
  for _,m in ipairs(mt) do
    parse_replay(m)
  end
end

function net_proc()
  if net_err then
    net_abort()
    return
  end
  local ts=socket.gettime()
  local ret=socket.select(allsocks,nil,0)
  local msg
  if ret[sock] then
    msg=net_read(ts)
  end
  if ts>=timeout then
    console.msg("! connection timed out")
    net_err="timeout"
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

local msg_ts
local rep_dt
local rep_m
local repend=false
function rep_init()
  local s=replay()
  local t=str_split(s,"@")
  init_vars()
  msg_ts=tonumber(t[1])
  rep_parse(t[2])
  s=replay()
  t=str_split(s,"@")
  local ts=tonumber(t[1])
  rep_dt=ts-msg_ts
  msg_ts=ts
  rep_m=t[2]
  love.draw=main_draw
  love.update=main_update
  love.quit=main_quit
  love.keypressed=main_keypressed
  love.keyreleased=main_keyreleased
  love.mousepressed=main_mousepressed
  love.mousereleased=main_mousereleased
end

function rep_proc(dt)
  if repend then
    return false
  end
  rep_dt=rep_dt-dt
  if rep_dt>0 then
    return true
  end
  rep_parse(rep_m)
  local s=replay()
  if not s then
    repend=true
    console.msg("replay has ended.")
    return false
  end
  local t=str_split(s,"@")
  local ts=tonumber(t[1])
  rep_dt=ts-msg_ts
  msg_ts=ts
  rep_m=t[2]
  return true
end
