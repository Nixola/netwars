-- vim:et

local function buy_device(pl,a)
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
  local price=cl.__members.price
  if not price then
    return
  end
  if pl.cash<price then
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
    end
    return
  end
  if a[2]=="c" and pl.havecmd then
    return
  end
  local o=cl:new(pl,x,y)
  if o.cl=="c" or o:chk_supply(x,y) then
    pl.cash=pl.cash-price
    o.idx=units:add(o)
    uhash:add(o)
    if a[2]=="c" then
      pl.havecmd=true
    end
    cput("PC:%d:%d:%d",pl.idx,pl.cash,pl.maxcash)
    cput("Un:%d:%s:%d:%d:%d",pl.idx,o.cl,o.idx,o.x,o.y)
  end
end

function parse_client(msg,pl,ts)
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
  if a[1]=="Um" then -- Move:idx:x:y:x:y
    if a.n<4 then
      return
    end
    local o=units[tonumber(a[2])]
    local x,y=tonumber(a[3]),tonumber(a[4])
    if o and o.pl==pl then
      if o:move(x,y) then
        cput("Um:%d:%s:%d:%d:%d:%d",o.idx,ts,o.x,o.y,o.mx,o.my)
      else
        cput("Up:%d:%d:%d",o.idx,o.x,o.y)
      end
    end
    return
  end
  if a[1]=="Sh" then -- Shot:u1:u2
    if a.n<3 then
      return
    end
    local u1=units[tonumber(a[2])]
    local u2=units[tonumber(a[3])]
    if u1 and u2 then
      u1:shot(u2)
    end
    return
  end
  if a[1]=="SH" then -- Shot:u1:d2
    if a.n<3 then
      return
    end
    local u1=units[tonumber(a[2])]
    local d2=devices[tonumber(a[3])]
    if u1 and d2 then
      u1:shot(d2)
    end
    return
  end
  if a[1]=="Ts" then -- Shot:d1:u2
    if a.n<3 then
      return
    end
    local d1=devices[tonumber(a[2])]
    local u2=units[tonumber(a[3])]
    if d1 and u2 then
      d1:shot(u2)
    end
    return
  end
  if a[1]=="Sp" then -- Shot:u1:u2
    if a.n<3 then
      return
    end
    local u1=units[tonumber(a[2])]
    local u2=units[tonumber(a[3])]
    if u1 and u2 then
      u1:transfer(u2)
    end
    return
  end
  if a[1]=="SP" then -- Shot:d1:u2
    if a.n<3 then
      return
    end
    local d1=devices[tonumber(a[2])]
    local u2=units[tonumber(a[3])]
    if d1 and u2 then
      d1:transfer(u2)
    end
    return
  end
  if a[1]=="SC" then -- Capture:u1:d2
    if a.n<3 then
      return
    end
    local u1=units[tonumber(a[2])]
    local d2=devices[tonumber(a[3])]
    if u1 and d2 then
      u1:capture(d2)
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
    if o and o.pl==pl and not o.online and o.pt<=0 then
      if o:move(x,y) then
        cput("Dm:%d:%d:%d",idx,o.x,o.y)
      end
    end
    return
  end
  if a[1]=="Lc" then -- Link:dev1:dev2
    if a.n<3 then
      return
    end
    local d1=devices[tonumber(a[2])]
    local d2=devices[tonumber(a[3])]
    if d1 and d2 and d1.pl==pl then
      local l=d1:connect(d2)
      if l then
        links:add(l)
        cput("Lc:%d:%d",d1.idx,d2.idx)
      end
    end
    return
  end
  if a[1]=="Lu" then -- Unlink:dev1:dev2
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
  if a[1]=="U" then -- Upgrade:idx
    if a.n<2 then
      return
    end
    local idx=tonumber(a[2])
    local o=devices[idx]
    if o and o.pl==pl then
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
      devices:del(o)
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

function devs_proc(dt)
  for _,o in pairs(devices) do
    o.pt=o.pt-dt
    o:check(dt)
    if not o.deleted and o.online and o.logic then
      o.dt=o.dt+dt
      if o.dt>=2.0 then
        o.dt=o.dt-2.0
        o:logic()
      end
    else
      o.dt=0
    end
  end
end

function units_proc(dt)
  for _,o in pairs(units) do
    if not o.deleted then
      if o:step(dt) then
        cput("Up:%d:%d:%d",o.idx,o.x,o.y)
      end
    end
  end
end
