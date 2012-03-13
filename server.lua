-- vim:et

local function buy_device(pl,a)
  if a.n<4 then
    return
  end
  local x,y=tonumber(a[3]),tonumber(a[4])
  local cl=devcl[a[2]]
  if not cl then
    return
  end
  local price=cl.__members.price
  if pl.cash>=price then
    pl.cash=pl.cash-price
    local o=cl:new(pl,x,y)
    o.idx=devices:add(o)
    --pl.msgq:put(string.format("Pc:%d:%d",pl.idx,pl.cash))
    mput("Pc:%d:%d",pl.idx,pl.cash)
    mput("Dn:%d:%s:%d:%d:%d",pl.idx,o.cl,o.idx,o.x,o.y)
  end
end

function parse_client(msg,pl)
  local a=str_split(msg,":")
  if a.n<1 then
    return
  end
  if a[1]=="B" then -- Buy:cl:x:y
    buy_device(pl,a)
    return
  end
  if a[1]=="D" then -- Del:idx
    if a.n<2 then
      return
    end
    local idx=tonumber(a[2])
    local o=devices[idx]
    if o and o.pl==pl then
      o:del_links()
      devices:del(o)
      if o.cl=="G" then
        generators[idx]=nil
      end
      mput("Dd:%d",idx)
    end
    return
  end
  if a[1]=="M" then -- Move:idx:x:y
    if a.n<4 then
      return
    end
    local idx=tonumber(a[2])
    local x,y=tonumber(a[3]),tonumber(a[4])
    local o=devices[idx]
    if o and o.pl==pl and (not o.online) then
      o:move(x,y)
      mput("Dm:%d:%d:%d",idx,o.x,o.y)
    end
    return
  end
  if a[1]=="S" then -- Switch:idx:online
    if a.n<3 then
      return
    end
    local idx=tonumber(a[2])
    local b=tonumber(a[3])==1
    local o=devices[idx]
    if o and o.pl==pl then
      o.online=b
      o.li=1
      o.edt=0
      b=b and 1 or 0
      mput("Ds:%d:%d",idx,b)
    end
    return
  end
  if a[1]=="L" then -- Link:dev1:dev2
    if a.n<3 then
      return
    end
    local d1=devices[tonumber(a[2])]
    local d2=devices[tonumber(a[3])]
    if d1 and d2 and d1.pl==pl then
      local l=d1:connect(d2)
      if l then
        links:add(l)
        mput("La:%d:%d",d1.idx,d2.idx)
      end
    end
    return
  end
  if a[1]=="U" then -- Unlink:dev1:dev2
    if a.n<3 then
      return
    end
    local d1=devices[tonumber(a[2])]
    local d2=devices[tonumber(a[3])]
    if d1 and d2 and d1.pl==pl then
      local l=d1:unlink(d2)
      if l then
        links:del(l)
        mput("Lu:%d:%d",d1.idx,d2.idx)
      end
    end
    return
  end
end

local function packet_hit(p)
  local pl=p.pl
  local o=p.dev2
  local v=p.v
  if o.pl==pl then
    -- Enqueued at friendly device
    if o.health<o.maxhealth then
      o:heal(v)
      mput("Ph:%d:%d",o.idx,o.health)
      return
    end
    if o.cl=="G" then
      return
    end
    if o.cl=="D" then
      pl.cash=pl.cash+v
      --pl.msgq:put(string.format("Pc:%d:%d",pl.idx,pl.cash))
      mput("Pc:%d:%d",pl.idx,pl.cash)
      return
    end
    o.pkt=o.pkt+v
    if o.pkt>100 then
      o.pkt=100
    end
    --pl.msgq:put(string.format("Pp:%d:%d",o.idx,o.pkt))
    return
  end
  -- Attacking enemy device
  o.health=o.health-v
  if o.health<1 then
    mput("Dd:%d",o.idx)
    o:del_links()
    devices:del(o)
    return
  end
  mput("Ph:%d:%d",o.idx,o.health)
end

function flow_packets(dt)
  local d1,d2,v
  for k,p in pairs(packets) do
    if p:flow(dt) then
      packet_hit(p)
      packets:del(p)
    end
  end
end

function emit_packets(dt)
  local i,d,p,l,c,ok
  for k,o in pairs(devices) do
    ok=false
    if o.cl=="G" and o.online then
      o.dt=o.dt+dt
      if o.dt>=3.0 then
        o.dt=0
        ok=true
        v=nil
      end
    end
    if o.pkt>0 then
      o.dt=o.dt+dt
      if o.dt>=0.5 then
        o.dt=0
        ok=true
        v=o.pkt>10 and 10 or o.pkt
      end
    end
    if ok then
      l=#o.links
      c=l
      i=o.li>l and 1 or o.li
      while c>0 do
        d=o.links[i].dev2
        i=i<l and i+1 or 1
        if o.pl~=d.pl or d.online then
          if v then
            o.pkt=o.pkt-v
            p=Packet:new(o,d,v,true)
            packets:add(p)
            mput("Pr:%d:%d:%d:%d",o.idx,d.idx,v,o.pkt)
            break
          end
          p=Packet:new(o,d,1,true)
          packets:add(p)
          mput("Pe:%d:%d:%d",o.idx,d.idx,1)
          break
        end
        c=c-1
      end
      o.li=i
    end
  end
end
