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
    local o=cl:new(pl,x,y)
    if a[2]=="B" then
      if pl.database then
        return
      end
      o.pwr=10
    end
    if o:chk_border(x,y) then
      pl.cash=pl.cash-price
      o.idx=devices:add(o)
      devhash:add(o)
      cput("PC:%d:%d:%d",pl.idx,pl.cash,pl.maxcash)
      if a[2]=="B" then
        cput("Dn:%d:%s:%d:%d:%d:%d",pl.idx,o.cl,o.idx,o.x,o.y,o.pwr)
        pl.database=true
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
      cput("Dd:%d",idx)
      if o.cl=="D" then
        cput("PC:%d:%d:%d",pl.idx,pl.cash,pl.maxcash)
      end
      devices:del(o)
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
    if o and o.pl==pl and (not o.online) and o.pt<=0 and #o.elinks<1 then
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
      b=b and 1 or 0
      cput("Ds:%d:%d",idx,b)
    end
    return
  end
  if a[1]=="Up" then -- Upgrade:idx
    if a.n<2 then
      return
    end
    local idx=tonumber(a[2])
    local o=devices[idx]
    if o and o.pl==pl then
      if pl.cash<o.uprice then
        return
      end
      if o.ec>=o.em then
        return
      end
      o.ec=o.ec+1
      pl.cash=pl.cash-o.uprice
      cput("PC:%d:%d:%d",pl.idx,pl.cash,pl.maxcash)
      cput("Du:%d:%d",idx,o.ec)
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
  local d1=p.d1
  local d2=p.d2
  local pl=d1.cl=="F" and d2.pl or d1.pl
  local v=p.v
  if d1.deleted or d1.blocked then
    return
  end
  if d2.deleted or d2.blocked then
    return
  end
  d1.pt=0.7
  d2.pt=0.7
  if d2.pl==pl then
    -- Enqueued at friendly device
    d2.dt2=0
    if d2.health<d2.maxhealth then
      d2.health=d2.health+v
      if d2.health>d2.maxhealth then
        d2.health=d2.maxhealth
      end
      if d1.rtr then
        mput("Ph:%d:%d:%d:%d",d1.idx,d2.idx,d2.health,d1.pkt)
      else
        mput("Ph:%d:%d:%d",d1.idx,d2.idx,d2.health)
      end
      return
    end
    if d2.cl=="D" then
      if pl.cash<pl.maxcash then
        pl.cash=pl.cash+math.floor(v/3)
        if pl.cash>pl.maxcash then
          pl.cash=pl.maxcash
        end
        mput("Pc:%d:%d:%d:%d",d1.idx,d2.idx,pl.cash,d1.pkt)
      end
      return
    end
    if not d2.rtr then
      if d1.rtr then
        mput("Ph:%d:%d:%d:%d",d1.idx,d2.idx,d2.health,d1.pkt)
      else
        mput("Ph:%d:%d:%d",d1.idx,d2.idx,d2.health)
      end
      return
    end
    d2.pkt=d2.pkt+v
    if d2.pkt>MAXP then
      d2.pkt=MAXP
    end
    if d1.rtr then
      mput("Pr:%d:%d:%d:%d",d1.idx,d2.idx,d1.pkt,d2.pkt)
    else
      mput("Pr:%d:%d::%d",d1.idx,d2.idx,d2.pkt)
    end
    return
  end
  -- Attacking enemy device
  d2.health=d2.health-v
  if d2.health<1 then
    if d2.cl=="G" then
      d2:takeover(pl)
      d2.blocked=true
      cput("Po:%d:%d:%d",d1.idx,d2.idx,d1.pkt)
      return
    end
    d2:delete()
    cput("Pd:%d:%d:%d",d1.idx,d2.idx,d1.pkt)
    if d2.cl=="D" then
      cput("PC:%d:%d:%d",d2.pl.idx,d2.pl.cash,d2.pl.maxcash)
    end
    devices:del(d2)
    return
  end
  mput("Ph:%d:%d:%d:%d",d1.idx,d2.idx,d2.health,d1.pkt)
end

function emit_packets(dt)
  local i,d,p,l,c,e,v,ok
  local pkts={}
  for _,o in pairs(devices) do
    o.pt=o.pt-dt
    o.blocked=false
    if not o.gotpwr then
      o.dt2=o.dt2+dt
      if o.dt2>=DEGT then
        o.dt2=o.dt-DEGT
        o.health=o.health-DEGV
        if o.health<1 then
          o:delete()
          cput("Dd:%d",o.idx)
          if o.cl=="D" then
            cput("PC:%d:%d:%d",o.pl.idx,o.pl.cash,o.pl.maxcash)
          end
          devices:del(o)
        else
          mput("Dh:%d:%d",o.idx,o.health)
        end
      end
    end
    if (not o.deleted) and (not o.pwr) then
      if o.lupd then
        o:upd_bdevs()
        o.lupd=false
      end
      local nok=true
      for _,d in pairs(o.bdevs) do
        if d.gotpwr then
          nok=false
          break
        end
      end
      o.gotpwr=not nok
      if o.cl=="D" then
        if nok and o.attch then
          o.pl.dcnt=o.pl.dcnt-1
          o.pl.maxcash=o.pl.dcnt*1000
          o.attch=false
          cput("PC:%d:%d:%d",o.pl.idx,o.pl.cash,o.pl.maxcash)
        end
        if (not nok) and (not o.attch) then
          o.pl.dcnt=o.pl.dcnt+1
          o.pl.maxcash=o.pl.dcnt*1000
          o.attch=true
          cput("PC:%d:%d:%d",o.pl.idx,o.pl.cash,o.pl.maxcash)
        end
      end
    end
    ok=0
    if (not o.deleted) and o.pl then
      l=#o.links
      if l>0 then
        if o.pwr then
          o.dt=o.dt+dt
          if o.dt>=2.0 then
            o.dt=o.dt-2.0
            ok=1
          end
        end
        if o.rtr then
          o.dt=o.dt+dt
          if o.dt>=2.0 then
            o.dt=o.dt-2.0
            ok=o.pkt>0 and 2 or 0
          end
        end
      else
        o.dt=0
      end
    end
    if ok>0 then
      c=l
      e=o.ec
      i=o.li>l and 1 or o.li
      while c>0 and e>0 do
        d=o.links[i].dev2
        i=i<l and i+1 or 1
        if o.pl~=d.pl or d.online then
          if ok==1 then
            v=o.pwr
            p={}
            p.d1=o
            p.d2=d
            p.v=v
            pkts[#pkts+1]=p
            e=e-1
          end
          if ok==2 then
            v=o.pkt>MAXV and MAXV or o.pkt
            o.pkt=o.pkt-v
            p={}
            p.d1=o
            p.d2=d
            p.v=v
            pkts[#pkts+1]=p
            e=e-1
            if o.pkt<1 then
              break
            end
          end
        end
        c=c-1
      end
      o.li=i
    end
  end
  for _,p in pairs(pkts) do
    packet_hit(p)
  end
end
