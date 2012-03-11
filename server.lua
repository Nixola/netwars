-- vim:et

local function buy_device(s,pl,a)
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
    if o.cl=="G" then
      generators[o.idx]=o
    end
    s:send(string.format("PLc:%d:%d\n",pl.idx,pl.cash))
    qput("Dn:%d:%s:%d:%.1f:%.1f\n",pl.idx,o.cl,o.idx,o.x,o.y)
  end
end

local function packet_flow(s,pl,p)
  if not p then
    return
  end
  local idx=p.idx
  local o=p.dev2
  p:dequeue()
  if p.pl==o.pl then
    if o.health<o.maxhealth then
      o:heal(p.v)
      qput("Ph:%d:%d:%d\n",idx,o.idx,o.health)
      packets:del(p)
      return
    end
    if o.cl=="D" then
      pl.cash=pl.cash+p.v
      qput("Pc:%d:%d\n",idx,pl.cash)
      return
    end
    if o.cl=="M" then
      local l=#o.blinks
      if l>0 then
        local i,d=o.li>l and 1 or o.li
        local c=l
        while c>0 do
          d=o.blinks[i].dev1
          i=i<l and i+1 or 1
          if d.online then
            p:route(o,d)
            qput("Pr:%d:%d:%d\n",idx,o.idx,d.idx)
            break
          end
          c=c-1
        end
        o.li=i
        if c>0 then
          return
        end
      end
      qput("Pd:%d\n",idx)
      packets:del(p)
      return
    end
    local l=#o.links
    if l>0 then
      local i,d=o.li>l and 1 or o.li
      local c=l
      while c>0 do
        d=o.links[i].dev2
        i=i<l and i+1 or 1
        if d.pl~=o.pl or d.online then
          p:route(o,d)
          qput("Pr:%d:%d:%d\n",idx,o.idx,d.idx)
          break
        end
        c=c-1
      end
      o.li=i
      if c>0 then
        return
      end
    end
    qput("Pd:%d\n",idx)
    packets:del(p)
    return
  end
  -- Attacking enemy device
  o.health=o.health-p.v
  if o.health<1 then
    qput("PD:%d:%d\n",idx,o.idx)
    o:delete()
    devices:del(o)
    packets:del(p)
    return
  end
  qput("Ph:%d:%d:%d\n",idx,o.idx,o.health)
  packets:del(p)
end

function read_client(s,pl)
  local str=s:receive()
  if not str then
    close_client(s,pl)
    return
  end
  local a=str_split(str,":")
  if a.n<2 then
    return
  end
  if a[1]=="B" then -- Buy:cl:x:y
    buy_device(s,pl,a)
    return
  end
  if a[1]=="D" then -- Del:idx
    if a.n<2 then
      return
    end
    local idx=tonumber(a[2])
    local o=devices[idx]
    if o.pl==pl then
      pl.cash=pl.cash+o.price
      o:delete()
      devices:del(o)
      if o.cl=="G" then
        generators[idx]=nil
      end
      qput("Dd:%d\n",idx)
      qput("PLc:%d:%d\n",pl.idx,pl.cash)
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
    if o.pl==pl and (not o.online) and o.pc<1 then
      o:move(x,y)
      qput("Dm:%d:%.1f:%.1f\n",o.idx,x,y)
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
    if o.pl==pl then
      o.online=b
      o.li=1
      o.dt=0
      b=b and 1 or 0
      qput("Ds:%d:%d\n",o.idx,b)
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
      links:add(l)
      qput("L:%d:%d\n",d1.idx,d2.idx)
    end
    return
  end
  if a[1]=="Pf" then -- Pf:idx
    if a.n<2 then
      return
    end
    local idx=tonumber(a[2])
    packet_flow(s,pl,packets[idx])
    return
  end
end

function emit_packets(dt)
  local i,d,p,l,c
  for k,o in pairs(generators) do
    if o.online then
      o.dt=o.dt+dt
      if o.dt>2 then
        o.dt=0
        l=#o.links
        if l>0 then
          c=l
          i=o.li>l and 1 or o.li
          while c>0 do
            d=o.links[i].dev2
            i=i<l and i+1 or 1
            if o.pl~=d.pl or d.online then
              p=Packet:new(o,d,1)
              p.idx=packets:add(p)
              qput("Pe:%d:%d:%d:%d\n",p.idx,o.idx,d.idx,1)
              break
            end
            c=c-1
          end
          o.li=i
        end
      end
    end
  end
end
