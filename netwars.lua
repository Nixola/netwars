#!/usr/bin/lua
-- vim:et

require "class"
require "sphash"
require "devices"
require "server"

players=ctable()
devices=ctable()
links=ctable()
packets=ctable()
devhash=sphash(100)

local sock=socket.udp()
local iptab={}
local ctlq=queue(1000)
local msgq=queue(1000)

function cput(fmt,...)
  ctlq:put(string.format(fmt,unpack(arg)))
end

function mput(fmt,...)
  msgq:put(string.format(fmt,unpack(arg)))
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
  if a[1]~="PLr" or a.n<2 then
    return
  end
  local pl=Player:new(1000)
  local h=ip..":"..port
  pl.ip=ip
  pl.port=port
  pl.name=a[2]
  pl.sendq=squeue()
  pl.recvq=rqueue()
  pl.syncq=squeue(500)
  pl.ts=ts+30
  pl.seq=1
  pl.insync=false
  pl.idx=players:add(pl)
  iptab[h]=pl
  local m=queue(5000)
  for _,o in pairs(players) do
    if o==pl then
      m:put(string.format("PLa:%d:%s:%d:me",o.idx,o.name,o.cash))
    else
      m:put(string.format("PLa:%d:%s:%d",o.idx,o.name,o.cash))
    end
  end
  for _,o in pairs(devices) do
    b=o.online and 1 or 0
    m:put(string.format("Da:%d:%s:%d:%d:%d:%d",o.pl.idx,o.cl,o.idx,b,o.x,o.y))
  end
  for _,o in pairs(links) do
    m:put(string.format("La:%d:%d",o.dev1.idx,o.dev2.idx))
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
end

function del_client(pl)
  local idx=pl.idx
  local h=pl.ip..":"..pl.port
  pl:disconnect()
  players:del(pl)
  iptab[h]=nil
  local msg=string.format("PLd:%d",idx)
  for _,o in pairs(players) do
    o.sendq:put(msg)
  end
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
  if a.n==2 and a[1]=="ACK" then
    if pl.insync then
      pl.sendq:del(tonumber(a[2]))
    else
      pl.syncq:del(tonumber(a[2]))
    end
  end
end

if not sock:setsockname("*",6352) then
  print("Error: bind() failed")
  return
end

local ret
local tm=socket.gettime()
local ts,dt
local allsocks={sock}
local q=queue()
local msg
while true do
  ret=socket.select(allsocks,nil,0.1)
  ts=socket.gettime()
  if ret[sock] then
    read_socket(ts)
  end
  for _,o in pairs(players) do
    if ts>=o.ts then
      del_client(o)
    else
      if (not o.insync) and o.gotok and o.syncq.len<1 then
        o.insync=true
      end
      msg=o.recvq:get(o.seq)
      if msg then
        o.seq=o.seq+1
        parse_client(msg,o)
      end
    end
  end
  if ts>=tm+0.1 then
    dt=ts-tm
    tm=ts
    flow_packets(dt)
    emit_packets(dt)
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
      for p in o.sendq:iter(ts,0.5) do
        sock:sendto(p,o.ip,o.port)
      end
    else
      local p=o.syncq:get(ts,0.5)
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
