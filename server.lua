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
  if price<10 then
    return
  end
  if pl.cash>=price then
    pl.cash=pl.cash-price
    local o=cl:new(pl,x,y)
    if a[2]=="G" or a[2]=="B" then
      o.pwr=5
    end
    if o:chk_border(x,y) then
      o.idx=devices:add(o)
      devhash:add(o)
      cput("Pc:%d:%d",pl.idx,pl.cash)
      if a[2]=="G" or a[2]=="B" then
        cput("Dn:%d:%s:%d:%d:%d:%d",pl.idx,o.cl,o.idx,o.x,o.y,o.pwr)
      else
        cput("Dn:%d:%s:%d:%d:%d",pl.idx,o.cl,o.idx,o.x,o.y)
      end
    end
  end
end

function parse_client(msg,pl)
  local a=str_split(msg,":")
  if a.n<2 then
    if a[1]=="OK" then
      pl.gotok=true
      return
    end
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
      o:delete()
      devices:del(o)
      cput("Dd:%d",idx)
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
    if o and o.pl==pl and (not o.online) and o.pc<1 and #o.elinks<1 then
      if o:move(x,y) then
        cput("Dm:%d:%d:%d",idx,o.x,o.y)
      end
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
      cput("Ds:%d:%d",idx,b)
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
        cput("La:%d:%d",d1.idx,d2.idx)
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
        l:del_packets()
        links:del(l)
        cput("Lu:%d:%d",d1.idx,d2.idx)
      end
    end
    return
  end
  if a[1]=="MSG" then -- MSG:~msg
    if a.n<2 then
      return
    end
    cput("MSG:%s:~%s",pl.name,a[2])
    return
  end
end

local function packet_hit(p)
  local pl=p.pl
  local o=p.dev2
  local v=p.v
  packets:del(p)
  if o.pl==pl then
    -- Enqueued at friendly device
    o.dt2=0
    if o.health<o.maxhealth then
      o.health=o.health+v
      if o.health>o.maxhealth then
        o.health=o.maxhealth
      end
      mput("Ph:%d:%d",o.idx,o.health)
      return
    end
    if o.cl=="G" then
      return
    end
    if o.cl=="D" then
      if pl.cash<pl.maxcash then
        pl.cash=pl.cash+v
        if pl.cash>pl.maxcash then
          pl.cash=pl.maxcash
        end
        mput("Pc:%d:%d",pl.idx,pl.cash)
      end
      return
    end
    o.pkt=o.pkt+v
    if o.pkt>MAXP then
      o.pkt=MAXP
    end
    o.upd=true
    return
  end
  -- Attacking enemy device
  o.health=o.health-v
  if o.health<1 then
    if o.cl=="G" then
      o:del_packets()
      o:del_links()
      o.pl=pl
      o.health=math.floor(o.maxhealth/2)
      o.online=false
      cput("Do:%d:%d:%d",o.idx,pl.idx,o.health)
      return
    end
    cput("Dd:%d",o.idx)
    o:delete()
    devices:del(o)
    return
  end
  mput("Ph:%d:%d",o.idx,o.health)
end

function flow_packets(dt)
  local d1,d2,v
  for _,p in pairs(packets) do
    if p:flow(dt) then
      packet_hit(p)
    end
  end
end

function emit_packets(dt)
  local i,d,p,l,c,v,ok
  for _,o in pairs(devices) do
    if not o.pwr then
      o.dt2=o.dt2+dt
      if o.dt2>=10.0 then
        o.dt2=o.dt-10.0
        o.health=o.health-10
        if o.health<1 then
          cput("Dd:%d",o.idx)
          o:delete()
          devices:del(o)
        else
          mput("Ph:%d:%d",o.idx,o.health)
        end
      end
    end
    ok=nil
    if o.pl and (not o.deleted)
      if o.cl=="G" or o.cl=="B" then
        o.dt=o.dt+dt
        if o.dt>=1.0 then
          o.dt=o.dt-1.0
          if o.dt>1.0 then
            o.dt=1.0
          end
          v=o.pwr
          ok=1
        end
      end
      if o.pkt>0 then
        o.dt=o.dt+dt
        if o.dt>=1.0 then
          o.dt=o.dt-1.0
          if o.dt>1.0 then
            o.dt=1.0
          end
          v=o.pkt>MAXV and MAXV or o.pkt
          ok=2
        end
      end
    end
    if ok and v>0 then
      l=#o.links
      c=l
      i=o.li>l and 1 or o.li
      while c>0 do
        d=o.links[i].dev2
        i=i<l and i+1 or 1
        if o.pl~=d.pl or d.online then
          if ok==1 then
            p=Packet:new(o,d,v)
            packets:add(p)
            mput("Pe:%d:%d:%d",o.idx,d.idx,v)
            break
          end
          if ok==2 then
            o.pkt=o.pkt-v
            p=Packet:new(o,d,v)
            packets:add(p)
            mput("Pr:%d:%d:%d:%d",o.idx,d.idx,v,o.pkt)
            break
          end
          break
        end
        c=c-1
      end
      o.li=i
      if o.cl=="R" and c<1 and o.upd then
        mput("Pi:%d:%d",o.idx,o.pkt)
        o.upd=false
      end
    end
  end
end
