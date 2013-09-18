-- vim:et

local cmd={}

cmd["MSG"]=function(pl,a,ts) -- MSG:~msg
  if a.n<2 then
    return
  end
  cput("MSG:%s:~%s",pl.name,a[2])
end

cmd["INFO"]=function(pl,a,ts) -- INFO:~msg
  if a.n<2 then
    return
  end
  cput("INFO:~%s",a[2])
end

cmd["OK"]=function(pl,a,ts)
  pl.gotok=true
end

cmd["B"]=function(pl,a,ts)
  if a.n<4 then
    return
  end
  local x,y=tonumber(a[3]),tonumber(a[4])
  local isdev=true
  local cl=d_cl[a[2]]
  if not cl then
    cl=u_cl[a[2]]
    isdev=false
  end
  if not cl then
    return
  end
  local price=cl.price
  if not price then
    return
  end
  if pl.cash<price then
    return
  end
  if a[2]=="B" and pl.started then
    return
  end
  if isdev then
    local o=cl:new(pl,x,y)
    if o:chk_border(x,y) then
      pl.cash=pl.cash-price
      o.idx=devices:add(o)
      dhash:add(o)
      cput("PC:%d:%d:%d",pl.idx,pl.cash,pl.maxcash)
      cput("Dn:%d:%s:%d:%d:%d",pl.idx,o.cl,o.idx,o.x,o.y)
      if a[2]=="B" then
        pl.started=true
      end
    end
    return
  end
  local o=cl:new(pl,x,y)
  if o:chk_supply(x,y) then
    pl.cash=pl.cash-price
    o.idx=units:add(o)
    uhash:add(o)
    rq_u:add(o,ts,TCK)
    cput("PC:%d:%d:%d",pl.idx,pl.cash,pl.maxcash)
    cput("Un:%d:%s:%d:%d:%d",pl.idx,o.cl,o.idx,o.x,o.y)
  end
end

cmd["S"]=function(pl,a,ts) -- Switch:idx:online
  if a.n<3 then
    return
  end
  local idx=tonumber(a[2])
  local b=tonumber(a[3])==1
  local o=devices[idx]
  if o and o.initok and o.gotpwr and o.pl==pl then
    o.online=b
    if b then
      rq_d:add(o,ts,TCK)
    end
    b=b and 1 or 0
    cput("Ds:%d:%d",idx,b)
  end
end

cmd["U"]=function(pl,a,ts) -- Upgrade:idx
  if a.n<2 then
    return
  end
  local idx=tonumber(a[2])
  local o=devices[idx]
  if o and o.initok and o.gotpwr and o.pl==pl then
    if pl.cash<o.price then
      return
    end
    if o.ec>=o.em then
      return
    end
    o.ec=o.ec+1
    pl.cash=pl.cash-o.price
    cput("PC:%d:%d:%d",pl.idx,pl.cash,pl.maxcash)
    cput("Du:%d:%d",idx,o.ec)
  end
end

cmd["D"]=function(pl,a,ts) -- Del:idx
  if a.n<2 then
    return
  end
  local idx=tonumber(a[2])
  local o=devices[idx]
  if o and o.pl==pl then
    o:delete()
    cput("Dd:%d",idx)
    devices:del(o)
  end
end

cmd["M"]=function(pl,a,ts) -- Move:idx:x:y
  if a.n<4 then
    return
  end
  local idx=tonumber(a[2])
  local x,y=tonumber(a[3]),tonumber(a[4])
  local o=devices[idx]
  if o and o.pl==pl and not o.online and o.pt<=0 then
    if o:move(x,y) then
      cput("Dm:%d:%d:%d",idx,o.x,o.y)
    end
  end
end

cmd["Lc"]=function(pl,a,ts) -- Link:dev1:dev2
  if a.n<3 then
    return
  end
  local d1=devices[tonumber(a[2])]
  local d2=devices[tonumber(a[3])]
  if d1 and d2 then
    if d1.pl==pl or (d1.cl=="G" and d2.pl==pl) then
      local l=d1:connect(d2)
      if l then
        links:add(l)
        cput("Lc:%d:%d",d1.idx,d2.idx)
      end
    end
  end
end

cmd["Lu"]=function(pl,a,ts) -- Unlink:dev1:dev2
  if a.n<3 then
    return
  end
  local d1=devices[tonumber(a[2])]
  local d2=devices[tonumber(a[3])]
  if d1 and d2 then
    if d1.pl==pl or (d1.cl=="G" and d2.pl==pl) then
      local l=d1:unlink(d2)
      if l then
        links:del(l)
        cput("Lu:%d:%d",d1.idx,d2.idx)
      end
    end
  end
end

cmd["LU"]=function(pl,a,ts) -- Unlink:dev
  if a.n<2 then
    return
  end
  local o=devices[tonumber(a[2])]
  if o and o.pl==pl then
    o:unlink_all()
    cput("LU:%d",o.idx)
  end
end

cmd["Ts"]=function(pl,a,ts) -- Shot:d1:u2
  if a.n<3 then
    return
  end
  local d1=devices[tonumber(a[2])]
  local u2=devices[tonumber(a[3])]
  if d1 and u2 then
    d1:shot(u2)
  end
end

cmd["TS"]=function(pl,a,ts) -- Shot:d1:d2
  if a.n<3 then
    return
  end
  local d1=devices[tonumber(a[2])]
  local d2=devices[tonumber(a[3])]
  if d1 and d2 then
    d1:shot(d2)
  end
end

cmd["Um"]=function(pl,a,ts) -- Move:idx:x:y:x:y
  if a.n<4 then
    return
  end
  local o=units[tonumber(a[2])]
  local x,y=tonumber(a[3]),tonumber(a[4])
  if o and o.pl==pl then
    if o:move(x,y) then
      rq_um:add(o,ts,0.02)
      cput("Um:%d:%s:%d:%d:%d:%d",o.idx,pl.ping,o.x,o.y,o.mx,o.my)
    else
      cput("Up:%d:%d:%d",o.idx,o.x,o.y)
    end
  end
end

cmd["Sh"]=function(pl,a,ts) -- Shot:u1:u2
  if a.n<3 then
    return
  end
  local u1=devices[tonumber(a[2])]
  local u2=devices[tonumber(a[3])]
  if u1 and u2 then
    u1:shot(u2)
  end
end

cmd["SH"]=function(pl,a,ts) -- Shot:u1:d2
  if a.n<3 then
    return
  end
  local u1=devices[tonumber(a[2])]
  local d2=devices[tonumber(a[3])]
  if u1 and d2 then
    u1:shot(d2)
  end
end

function parse_client(msg,pl,ts)
  local a=str_split(msg,":")
  local chunk=cmd[a[1]]
  if chunk then
    chunk(pl,a,ts)
  end
end

function scheduler(ts,dt)
  for _,o in pairs(devices) do
    o.pt=o.pt-dt
    o:check()
  end
  for o,d in rq_um:iter(ts,0.1) do
    if o.deleted then
      rq_um:del()
    elseif o:step(d) then
      rq_um:del()
      cput("Up:%d:%d:%d",o.idx,o.x,o.y)
    end
  end
  for o in rq_d:iter(ts,TCK) do
    if not o.deleted and o.online and o.logic then
      o:logic()
    else
      rq_d:del()
    end
  end
  for o in rq_u:iter(ts,TCK) do
    if not o.deleted then
      o:logic()
    else
      rq_u:del()
    end
  end
end
