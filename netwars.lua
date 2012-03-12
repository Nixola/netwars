#!/usr/bin/lua
-- vim:et

require "class"
require "devices"
require "server"

players=ctable()
devices=ctable()
links=ctable()
generators={}
local iptab={}

local sock=socket.udp()

if not sock:setsockname("*",6352) then
  print("Error: bind() failed")
  return
end

local tm1,tm2
local dt=0

function qput(fmt,...)
  local q={v=string.format(fmt,unpack(arg))}
  queue[#queue+1]=q
end

function qsput(s,fmt,...)
  local q={s=s,v=string.format(fmt,unpack(arg))}
  queue[#queue+1]=q
end

local function enqueue(q,t)
  local len,p,l
  for i,m in ipairs(t) do
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
end

local function new_client(str,ip,port)
  local a=str_split(str,":")
  if not s then
    return
  end
  local pl=Player:new(200)
  local q={}
  local b
  pl.ip=ip
  pl.port=port
  pl.idx=players:add(pl)
  pl.queue={}
  for k,o in pairs(players) do
    if o==pl then
      q[#q+1]=string.format("PLa:%d:%d:me",o.idx,o.cash)
    else
      q[#q+1]=string.format("PLa:%d:%d",o.idx,o.cash)
    end
  end
  for k,o in pairs(devices) do
    b=o.online and 1 or 0
    q[#q+1]=string.format("Da:%d:%s:%d:%d:%d:%d",o.pl.idx,o.cl,o.idx,b,o.x,o.y)
  end
  for k,o in pairs(links) do
    q[#q+1]=string.format("La:%d:%d\n",o.dev1.idx,o.dev2.idx)
  end
  enqueue(pl.queue,q)
  for k,v in pairs(q) do
    s:send(v)
  end
  s:send("DONE\n")
  qsput(s,"PLa:%d:%d\n",pl.idx,pl.cash)
end

function close_client(s,pl)
  local si=pl.si
  local idx=pl.idx
  s:close()
  for k,o in pairs(generators) do
    if o.pl==pl then
      generators[k]=nil
    end
  end
  pl:disconnect()
  players:del(pl)
  qput("PLd:%d\n",idx)
end

local function read_socket()
  local str,ip,port=sock:receivefrom()
  local h=ip..":"..port
  local pl=iptab[h]
  if not pl then
    new_client(str,ip,port)
    return
  end
  local pt=str_split(str,"|")
  for i,p in ipairs(pt) do
    parse_client(p,pl)
  end
end

local function flush_queue()
end

local ret
local tm1=socket.gettime()
local allsocks={sock}
while true do
  ret=socket.select(allsocks,nil,1)
  queue={}
  if ret[sock] then
    read_socket()
  end
  tm2=socket.gettime()
  if tm2>tm1 then
    dt=tm2-tm1
    tm1=tm2
    emit_packets(dt)
  end
  for k,q in pairs(queue) do
    for k,s in pairs(socks) do
      if q.s~=s then
        s:send(q.v)
      end
    end
  end
end
