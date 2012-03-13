#!/usr/bin/lua
-- vim:et

require "class"
require "devices"
require "server"

players=ctable()
devices=ctable()
links=ctable()
packets=ctable()

local sock=socket.udp()
local iptab={}
local msgq=queue()
local pktq=queue()

if not sock:setsockname("*",6352) then
  print("Error: bind() failed")
  return
end

function mput(fmt,...)
  msgq:put(string.format(fmt,unpack(arg)))
end

local function enqueue(mq)
  local q=queue()
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

local function new_client(str,ip,port)
  print("new client: ",str)
  local a=str_split(str,":")
  if a[1]~="PLr" then
    return
  end
  local pl=Player:new(200)
  local h=ip..":"..port
  pl.ip=ip
  pl.port=port
  pl.msgq=queue()
  pl.idx=players:add(pl)
  iptab[h]=pl
  local m=queue()
  for k,o in pairs(players) do
    if o==pl then
      m:put(string.format("PLa:%d:%d:me",o.idx,o.cash))
    else
      m:put(string.format("PLa:%d:%d",o.idx,o.cash))
    end
  end
  for k,o in pairs(devices) do
    b=o.online and 1 or 0
    m:put(string.format("Da:%d:%s:%d:%d:%d:%d",o.pl.idx,o.cl,o.idx,b,o.x,o.y))
  end
  for k,o in pairs(links) do
    m:put(string.format("La:%d:%d\n",o.dev1.idx,o.dev2.idx))
  end
  m:put("DONE")
  local q=enqueue(m)
  for p in q:iter() do
    sock:sendto(p,ip,port)
  end
  msg=string.format("PLa:%d:%d",pl.idx,pl.cash)
  for k,o in pairs(players) do
    if o~=pl then
      sock:sendto(msg,o.ip,o.port)
    end
  end
  print("client added")
end

function del_client(pl)
  local idx=pl.idx
  local h=pl.ip..":"..pl.port
  pl:disconnect()
  players:del(pl)
  iptab[h]=nil
  mput("PLd:%d",idx)
  print("client deleted")
end

local function read_socket()
  local str,ip,port=sock:receivefrom()
  if not str then
    return
  end
  local h=ip..":"..port
  local pl=iptab[h]
  if not pl then
    return new_client(str,ip,port)
  end
  print("recv client: ",str)
  if str=="PLu" then
    return del_client(pl)
  end
  local pt=str_split(str,"|")
  for i,m in ipairs(pt) do
    parse_client(m,pl)
  end
end

local function flush_msgs()
  local q=enqueue(msgq)
  for p in q:iter() do
    for k,o in pairs(players) do
      sock:sendto(p,o.ip,o.port)
    end
  end
end

local ret
local tm1=socket.gettime()
local tm2,dt
local allsocks={sock}
while true do
  ret=socket.select(allsocks,nil,0.1)
  msgq:clear()
  if ret[sock] then
    read_socket()
  end
  tm2=socket.gettime()
  if tm2>=tm1+0.1 then
    dt=tm2-tm1
    tm1=tm2
    flow_packets(dt)
    emit_packets(dt)
  end
  flush_msgs()
end
