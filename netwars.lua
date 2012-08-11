#!/usr/bin/lua
-- vim:et

if not socket then
  require "socket"
end
require "class"
require "sphash"
require "devices"
require "devices_srv"
require "server"

SRV=true
dirty=false

player_cnt=0
players=ctable()
devices=ctable()
links=storage()
hash=sphash(200)

local sock=socket.udp()
local iptab={}
local ctlq=queue(1000)
local msgq=queue(1000)

function cput(fmt,...)
  ctlq:put(string.format(fmt,...))
end

function mput(fmt,...)
  msgq:put(string.format(fmt,...))
end

local function enqueue(q,mq)
  local len,p,l
  for m in mq:iter() do
    l=m:len()
    if not p then
      p=m
      len=l
    elseif len+l>=500 then
      q:put(p)
      p=m
      len=l
    else
      p=p.."|"..m
      len=len+l+1
    end
  end
  if p then
    q:put(p)
  end
  return q
end

local function new_client(str,ts,ip,port)
  local a=str_split(str,":")
  if a[1]~="PLr" or a.n<3 then
    return
  end
  if a[3]~=NVER then
    sock:sendto("ERR:~Client version mismatch.",ip,port)
    return
  end
  local pl=Player:new(3000)
  local h=ip..":"..port
  pl.ip=ip
  pl.port=port
  pl.name=a[2]
  pl.sendq=squeue()
  pl.recvq=rqueue()
  pl.syncq=squeue(500)
  pl.ts=ts+30
  pl.ping=0
  pl.pts=ts
  pl.seq=1
  pl.insync=false
  pl.idx=players:add(pl)
  player_cnt=player_cnt+1
  iptab[h]=pl
  local m=queue(5000)
  for _,o in pairs(players) do
    if o==pl then
      m:put(string.format("PLa:%d:%s:%d:me:%s",o.idx,o.name,o.cash,ts))
    else
      m:put(string.format("PLa:%d:%s:%d",o.idx,o.name,o.cash))
    end
  end
  local b,i
  for _,o in pairs(devices) do
    b=o.online and 1 or 0
    i=o.pl and o.pl.idx or 0
    if o.cl=="G" then
      m:put(string.format("Da:%d:%s:%d:%d:%d:%d:%d:%d",i,o.cl,o.idx,o.health,b,o.x,o.y,o.pwr))
    elseif o.ec then
      m:put(string.format("Da:%d:%s:%d:%d:%d:%d:%d:%d:%d",i,o.cl,o.idx,o.health,b,o.x,o.y,o.pkt,o.ec))
    elseif o.maxpkt then
      m:put(string.format("Da:%d:%s:%d:%d:%d:%d:%d:%d",i,o.cl,o.idx,o.health,b,o.x,o.y,o.pkt))
    else
      m:put(string.format("Da:%d:%s:%d:%d:%d:%d:%d",i,o.cl,o.idx,o.health,b,o.x,o.y))
    end
  end
  for _,o in pairs(links) do
    m:put(string.format("Lc:%d:%d",o.dev1.idx,o.dev2.idx))
  end
  m:put("DONE")
  enqueue(pl.syncq,m)
  pl.sendq.seq=pl.syncq.seq
  local msg=string.format("PLa:%d:%s:%d",pl.idx,pl.name,pl.cash)
  for _,o in pairs(players) do
    if o~=pl then
      o.sendq:put(msg)
    end
  end
  print(string.format("%s has connected.",pl.name))
  dirty=true
end

function del_client(pl)
  local idx=pl.idx
  local h=pl.ip..":"..pl.port
  pl:disconnect()
  players:del(pl)
  player_cnt=player_cnt-1
  iptab[h]=nil
  local msg=string.format("PLd:%d",idx)
  for _,o in pairs(players) do
    o.sendq:put(msg)
  end
  print(string.format("%s disconnected.",pl.name))
end

local function read_socket(ts)
  local str,ip,port=sock:receivefrom()
  if not str then
    return
  end
  local h=ip..":"..port
  local pl=iptab[h]
  if not pl then
    return new_client(str,ts,ip,port)
  end
  pl.ts=ts+30
  if str:find("!",1,true) then
    local s=pl.recvq:put(str)
    if not s then
      return del_client(pl)
    end
    sock:sendto(string.format("ACK:%d",s),pl.ip,pl.port)
    return
  end
  if str=="KEEPALIVE" then
    return
  end
  if str=="PING" then
    sock:sendto("PONG",pl.ip,pl.port)
    return
  end
  if str=="DISCONNECT" then
    return del_client(pl)
  end
  local a=str_split(str,":")
  if a[1]=="ACK" and a.n==2 then
    if pl.insync then
      pl.sendq:del(tonumber(a[2]))
    else
      pl.syncq:del(tonumber(a[2]))
    end
    return
  end
  if a[1]=="PONG" and a.n==2 then
    local ping=(ts-tonumber(a[2]))/2
    pl.ping=(pl.ping+ping)/2
    return
  end
end

function add_G(x,y,pwr)
  local o=Generator:new(nil,x,y)
  o.pwr=pwr>MAXV and MAXV or pwr
  if o:chk_border(x,y) then
    o.idx=devices:add(o)
    o.dt=math.random()*2
    o.online=true
    hash:add(o)
    return o
  end
  return nil
end

function add_R(x,y,ec)
  local o=Router:new(nil,x,y)
  o.ec=ec>o.em and o.em or ec
  if o:chk_border(x,y) then
    o.idx=devices:add(o)
    o.dt=math.random()*2
    o.online=true
    hash:add(o)
    return o
  end
  return nil
end

function add_T(x,y,ec)
  local o=Tower:new(nil,x,y)
  if o:chk_border(x,y) then
    o.idx=devices:add(o)
    o.dt=math.random()*2
    o.online=true
    hash:add(o)
    return o
  end
  return nil
end

if not sock:setsockname("*",6352) then
  print("Error: bind() failed")
  return
end

mapchunk=nil
if arg[1] then
  local chunk=loadfile(arg[1])
  mapchunk=chunk(arg[2])
  mapchunk()
end

local ret
local tm=socket.gettime()
local ts,dt
local allsocks={sock}
local q=queue()
local msg
while true do
  if dirty and player_cnt<1 then
    for _,o in pairs(devices) do
      o:del_links()
      devices:del(o)
      hash:del(o)
    end
    if mapchunk then
      mapchunk()
    end
    dirty=false
  end
  ret=socket.select(allsocks,nil,0.3)
  ts=socket.gettime()
  if ret[sock] then
    read_socket(ts)
  end
  for _,o in pairs(players) do
    if ts>=o.ts then
      del_client(o)
    else
      if not o.insync and o.gotok and o.syncq.len<1 then
        o.insync=true
      end
      msg=o.recvq:get(o.seq)
      if msg then
        o.seq=o.seq+1
        parse_client(msg,o,ts)
      end
    end
  end
  if ts>tm+0.25 then
    dt=ts-tm
    tm=ts
    devs_proc(dt)
  end
  enqueue(q,ctlq)
  ctlq:clear()
  for p in q:ited() do
    for _,o in pairs(players) do
      o.sendq:put(p)
    end
  end
  for _,o in pairs(players) do
    if o.insync then
      for p in o.sendq:iter(ts,1.0) do
        sock:sendto(p,o.ip,o.port)
      end
    else
      local p=o.syncq:get(ts,1.0)
      if p then
        sock:sendto(p,o.ip,o.port)
      end
    end
  end
  enqueue(q,msgq)
  msgq:clear()
  for p in q:ited() do
    for _,o in pairs(players) do
      if o.insync then
        sock:sendto(p,o.ip,o.port)
      end
    end
  end
end
