#!/usr/bin/lua
-- vim:et

require "class"
require "devices"
require "server"

players=ctable()
devices=ctable()
links=ctable()
generators={}

socks={}
allsocks={}
psocks={}

local servsock=socket.tcp()

if not servsock:bind("0.0.0.0",6352) then
  print("Error: bind() failed")
  return
end
if not servsock:listen() then
  print("Error: listen() failed")
  return
end
allsocks[1]=servsock

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

local function new_client(s)
  local s=servsock:accept()
  if not s then
    return
  end
  local pl=Player:new(200)
  local si=#socks+1
  local q={}
  local b
  pl.idx=players:add(pl)
  pl.si=si
  socks[si]=s
  psocks[si]=pl
  allsocks={servsock}
  for k,v in pairs(socks) do
    allsocks[#allsocks+1]=v
  end
  for k,o in pairs(players) do
    if o==pl then
      q[#q+1]=string.format("PLa:%d:%d:me\n",o.idx,o.cash)
    else
      q[#q+1]=string.format("PLa:%d:%d\n",o.idx,o.cash)
    end
  end
  for k,o in pairs(devices) do
    b=o.online and 1 or 0
    q[#q+1]=string.format("Da:%d:%s:%d:%d:%.1f:%.1f\n",o.pl.idx,o.cl,o.idx,b,o.x,o.y)
  end
  for k,o in pairs(links) do
    q[#q+1]=string.format("La:%d:%d\n",o.dev1.idx,o.dev2.idx)
  end
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
  socks[si]=nil
  psocks[si]=nil
  for k,o in pairs(generators) do
    if o.pl==pl then
      generators[k]=nil
    end
  end
  pl:disconnect()
  players:del(pl)
  allsocks={servsock}
  for k,v in pairs(socks) do
    allsocks[#allsocks+1]=v
  end
  qput("PLd:%d\n",idx)
end

local ret
local tm1=os.time()
while true do
  ret=socket.select(allsocks,nil,1.0)
  queue={}
  if ret[servsock] then
    new_client()
  end
  for k,s in pairs(socks) do
    if ret[s] then
      read_client(s,psocks[k])
    end
  end
  tm2=os.time()
  if tm2>tm1 then
    dt=os.difftime(tm2,tm1)
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
