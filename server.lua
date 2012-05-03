-- vim:et

local function buy_device(pl,a)
  if a.n<4 then
    return
  end
  local x,y=tonumber(a[3]),tonumber(a[4])
  local isunit=false
  local cl=d_cl[a[2]]
  if not cl then
    cl=u_cl[a[2]]
    isunit=true
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
  if isunit then
    if a[2]=="c" and pl.havecmd then
      return
    end
    local o=cl:new(pl,x,y)
    pl.cash=pl.cash-price
    o.idx=units:add(o)
    uhash:add(o)
    if a[2]=="c" then
      pl.havecmd=true
    end
    cput("PC:%d:%d:%d",pl.idx,pl.cash,pl.maxcash)
    cput("Un:%d:%s:%d:%d:%d",pl.idx,o.cl,o.idx,o.x,o.y)
    return
  end
  local o=cl:new(pl,x,y)
  if o:chk_border(x,y) then
    pl.cash=pl.cash-price
    o.idx=devices:add(o)
    dhash:add(o)
    cput("PC:%d:%d:%d",pl.idx,pl.cash,pl.maxcash)
    cput("Dn:%d:%s:%d:%d:%d",pl.idx,o.cl,o.idx,o.x,o.y)
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
  if a[1]=="Um" then -- Move:dev:x:y
    if a.n<4 then
      return
    end
    local o=units[tonumber(a[2])]
    local x,y=tonumber(a[3]),tonumber(a[4])
    if o and o.pl==pl then
      if o:move(x,y) then
        cput("Um:%d:%s:%d:%d",o.idx,ts,o.mx,o.my)
      else
        cput("Up:%d:%d:%d",o.idx,o.x,o.y)
      end
    end
    return
  end
  if a[1]=="Ut" then -- Target:dev:...
    if a.n<2 then
      return
    end
    local o=units[tonumber(a[2])]
    local idx=tonumber(a[3])
    if o and o.pl==pl then
      if idx and devices[idx] then
        o.targ=devices[idx]
        cput("Ut:%d:%d",o.idx,idx)
      else
        o.targ=nil
        cput("Ut:%d:",o.idx)
      end
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
    if o and o.pl==pl and (not o.online) and o.pt<=0 then
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
  if a[1]=="D" then -- Del:idx
    if a.n<2 then
      return
    end
    local idx=tonumber(a[2])
    local o=devices[idx]
    if o and o.pl==pl then
      o:delete()
      cput("Dd:%d",idx)
      if o.cl=="V" then
        cput("PC:%d:%d:%d",pl.idx,pl.cash,pl.maxcash)
      end
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

local function packet_hit(p)
  local d1=p.d1
  local d2=p.d2
  local pl=d2.pl
  local v=p.v
  if d1.deleted or d1.blocked then
    return
  end
  if d2.deleted or d2.blocked then
    return
  end
  d1.pt=0.7
  d2.pt=0.7
  -- Enqueued at device
  d2.dt2=0
  if d2.cl=="V" then
    pl.cash=pl.cash+v
    if pl.cash>pl.maxcash then
      pl.cash=pl.maxcash
    end
    mput("Pc:%d:%d:%d:%d",d1.idx,d2.idx,pl.cash,d1.pkt)
    return
  end
  if not d2.rtr then
    return
  end
  d2.pkt=d2.pkt+v
  if d2.pkt>d2.maxpkt then
    d2.pkt=d2.maxpkt
  end
  if d1.rtr then
    mput("Pr:%d:%d:%d:%d",d1.idx,d2.idx,d1.pkt,d2.pkt)
  else
    mput("Pr:%d:%d::%d",d1.idx,d2.idx,d2.pkt)
  end
  return
end

local function emit_packets(o,dt)
  if o.deleted then
    return
  end
  if not o.initok then
    return
  end
  if not o.online then
    return
  end
  local i,d,p,l,c,e,v,ok
  local pkts={}
  ok=0
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
  if ok==0 then
    return
  end
  c=l
  e=o.ec
  i=o.li>l and 1 or o.li
  while c>0 and e>0 do
    d=o.links[i].dev2
    i=i<l and i+1 or 1
    if d.online and ((not d.maxpkt) or d.pkt<d.maxpkt) then
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
  for _,p in pairs(pkts) do
    packet_hit(p)
  end
end

local function chk_device(o,dt)
  if o.deleted then
    return
  end
  if not o.initok then
    return
  end
  if not o.gotpwr then
    o.dt2=o.dt2+dt
    if o.dt2>=DEGT then
      o:delete()
      cput("Dd:%d",o.idx)
      if o.cl=="V" then
        cput("PC:%d:%d:%d",o.pl.idx,o.pl.cash,o.pl.maxcash)
      end
      devices:del(o)
      return
    end
  end
  if not o.pwr then
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
    if o.cl=="V" then
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
end

function devs_proc(dt)
  for _,o in pairs(devices) do
    o.pt=o.pt-dt
    o.blocked=false
    chk_device(o,dt)
    emit_packets(o,dt)
  end
end

function Commander:capture(targ)
  if targ.pl==self.pl then
    return
  end
  if targ.cpl~=self.pl then
    targ.cpl=self.pl
    targ.ccnt=0
  end
  targ.ccnt=targ.ccnt+1
  if targ.ccnt<CAPTC then
    mput("Sc:%d:%d:%d",self.idx,targ.idx,self.pkt)
    return
  end
  cput("SO:%d:%d:%d",self.idx,targ.idx,self.pkt)
  targ:takeover(self.pl)
  self.targ=nil
end

function Commander:attack(targ)
  targ.health=targ.health-10
  if targ.health<1 then
    cput("Sd:%d:%d:%d",self.idx,targ.idx,self.pkt)
  else
    cput("Sh:%d:%d:%d:%d",self.idx,targ.idx,self.pkt,targ.health)
  end
end

function Commander:logic()
  if self.targ then
    if self.targ.deleted then
      self.targ=nil
    else
      local targ=self.targ
      local tx,ty=targ.x-self.x,targ.y-self.y
      len=math.sqrt(tx*tx+ty*ty)
      if len<BEAMR and targ.pl~=self.pl then
        self:capture(targ)
        return
      end
    end
  end
  local t=uhash:get(self.x-SHOTR,self.y-SHOTR,self.x+SHOTR,self.y+SHOTR)
  local targ
  local tlen=SHOTR
  local tx,ty,len
  for _,u in pairs(t) do
    if u~=self and u.pl~=self.pl then
      tx,ty=u.x-self.x,u.y-self.y
      len=math.sqrt(tx*tx+ty*ty)
      if len<tlen then
        targ=u
        tlen=len
      end
    end
  end
  if targ then
    self:attack(targ)
  end
end

function Engineer:heal(targ)
  if targ.isdev then
    local v=self.pkt>MAXV and MAXV or self.pkt
    self.pkt=self.pkt-v
    targ.health=targ.health-v*5
    if targ.health>targ.maxhealth then
      targ.health=targ.maxhealth
    end
    cput("SH:%d:%d:%d:%d",self.idx,targ.idx,self.pkt,targ.health)
  else
    local v=self.pkt>MAXV and MAXV or self.pkt
    self.pkt=self.pkt-v
    targ.health=targ.health-v*5
    if targ.health>targ.maxhealth then
      targ.health=targ.maxhealth
    end
    cput("Sh:%d:%d:%d:%d",self.idx,targ.idx,self.pkt,targ.health)
  end
end

function Engineer:capture(targ)
  if targ.pl==self.pl then
    return
  end
  if self.pkt<MAXV then
    return
  end
  self.pkt=self.pkt-MAXV
  if targ.cpl~=self.pl then
    targ.cpl=self.pl
    targ.ccnt=0
  end
  targ.ccnt=targ.ccnt+1
  if targ.ccnt<CAPTC then
    mput("Sc:%d:%d:%d",self.idx,targ.idx,self.pkt)
    return
  end
  cput("SO:%d:%d:%d",self.idx,targ.idx,self.pkt)
  targ:takeover(self.pl)
  self.targ=nil
end

function Engineer:logic()
  if self.pkt<1 then
    return
  end
  if self.targ then
    if self.targ.deleted then
      self.targ=nil
    else
      local targ=self.targ
      local tx,ty=targ.x-self.x,targ.y-self.y
      len=math.sqrt(tx*tx+ty*ty)
      if len<BEAMR then
        if targ.pl~=self.pl then
          self:capture(targ)
          return
        elseif targ.health<targ.maxhealth then
          self:heal(targ)
          return
        end
      end
    end
  end
  local t=uhash:get(self.x-BEAMR,self.y-BEAMR,self.x+BEAMR,self.y+BEAMR)
  local targ=nil
  local tlen=BEAMR
  local tx,ty,len
  for _,u in pairs(t) do
    if u~=self and u.pl==self.pl then
      tx,ty=u.x-self.x,u.y-self.y
      len=math.sqrt(tx*tx+ty*ty)
      if len<tlen and u.health<u.maxhealth then
        targ=u
        tlen=len
      end
    end
  end
  if targ then
    self:heal(targ)
  end
end

function Tank:attack(targ)
  if targ.isdev then
    self.pkt=self.pkt-1
    targ.health=targ.health-5
    if targ.health<1 then
      cput("SD:%d:%d:%d",self.idx,targ.idx,self.pkt)
      targ:delete()
      devices:del(targ)
      self.targ=nil
    else
      cput("SH:%d:%d:%d:%d",self.idx,targ.idx,self.pkt,targ.health)
    end
  else
    self.pkt=self.pkt-1
    targ.health=targ.health-5
    if targ.health<1 then
      cput("Sd:%d:%d:%d",self.idx,targ.idx,self.pkt)
      targ:delete()
      units:del(targ)
    else
      cput("Sh:%d:%d:%d:%d",self.idx,targ.idx,self.pkt,targ.health)
    end
  end
end

function Tank:logic()
  if self.pkt<1 then
    return
  end
  if self.targ then
    if self.targ.deleted then
      self.targ=nil
    else
      local targ=self.targ
      local tx,ty=targ.x-self.x,targ.y-self.y
      len=math.sqrt(tx*tx+ty*ty)
      if len<SHOTR then
        self:attack(targ)
        return
      end
    end
  end
  local t=uhash:get(self.x-SHOTR,self.y-SHOTR,self.x+SHOTR,self.y+SHOTR)
  local targ=nil
  local tlen=SHOTR
  local tx,ty,len
  for _,u in pairs(t) do
    if u~=o and u.pl~=ME then
      tx,ty=u.x-o.x,u.y-o.y
      len=math.sqrt(tx*tx+ty*ty)
      if len<SHOTR then
        targ=u
        tlen=len
        break
      end
    end
  end
  if targ then
    self:attack(targ)
  end
end

function Supply:transfer(targ)
  local v=self.pkt>MAXV and MAXV or self.pkt
  self.pkt=self.pkt-v
  targ.pkt=targ.pkt+v
  if targ.pkt>targ.maxpkt then
    targ.pkt=targ.maxpkt
  end
  cput("Sp:%d:%d:%d:%d",self.idx,targ.idx,self.pkt,targ.pkt)
end

function Supply:logic()
  if self.pkt<1 then
    return
  end
  local t=uhash:get(self.x-BEAMR,self.y-BEAMR,self.x+BEAMR,self.y+BEAMR)
  local targ=nil
  local tlen=BEAMR
  local tx,ty,len
  for _,u in pairs(t) do
    if u~=self and u.pl==self.pl then
      tx,ty=u.x-self.x,u.y-self.y
      len=math.sqrt(tx*tx+ty*ty)
      if len<BEAMR and u.pkt<u.maxpkt then
        targ=u
        tlen=len
      end
    end
  end
  if targ then
    self:transfer(targ)
  end
end

function units_proc(dt)
  for _,o in pairs(units) do
    if o:step(dt) then
      cput("Up:%d:%d:%d",o.idx,o.x,o.y)
    end
    o.dt=o.dt+dt
    if o.dt>=2.0 then
      o.dt=o.dt-2.0
      o:logic()
    end
  end
end
