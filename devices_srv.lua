-- vim:et

function Device:link(dev) -- use only in map generators
  self.initok=true
  local l=self:connect(dev)
  if l then
    links:add(l)
  end
  dev:upd_bdevs()
end

function Device:upd_bdevs()
  local tmp={}
  for _,l in ipairs(self.blinks) do
    if l.dev2==self then
      tmp[#tmp+1]=l.dev1
    end
  end
  self.bdevs=tmp
  self.lupd=false
end

function Device:chk_bdevs()
  if self.cl=="R" and #self.bdevs>0 then
    local path={}
    local ok=false
    local tmp=self.bdevs
    local tmp2={}
    path[self]=self
    while #tmp>0 do
      for _,d in pairs(tmp) do
        if not path[d] then
          if d.pwr then
            ok=true
            break
          end
          path[d]=d
          for _,o in pairs(d.bdevs) do
            tmp2[#tmp2+1]=o
          end
        end
      end
      if ok then
        break
      end
      tmp=tmp2
      tmp2={}
    end
    if self.gotpwr~=ok then
      for _,d in pairs(path) do
        d.gotpwr=ok
      end
    end
  end
end

function Device:check(dt)
  if self.deleted then
    return
  end
  if not self.initok then
    return
  end
  if not self.gotpwr then
    self.dt2=self.dt2+dt
    if self.dt2>=DEGT then
      self:delete()
      cput("Dd:%d",self.idx)
      devices:del(self)
      return
    end
  else
    self.dt2=0
  end
  if not self.pwr then
    if self.lupd then
      self:upd_bdevs()
      self:chk_bdevs()
      return
    end
    local ok=false
    for _,d in pairs(self.bdevs) do
      if d.gotpwr then
        ok=true
        break
      end
    end
    self.gotpwr=ok
    if self.cl=="V" then
      if not ok and self.attch then
        self:update("detach")
      end
      if ok and not self.attch then
        self:update("attach")
      end
    end
  end
end

function Device:packet(dev,v)
  if self.deleted then
    return
  end
  if self.health<self.maxhealth then
    self.health=min(self.health+v,self.maxhealth)
    if dev.maxpkt then
      mput("Ph:%d:%d:%d:%d",dev.idx,self.idx,dev.pkt,self.health)
    else
      mput("Ph:%d:%d::%d",dev.idx,self.idx,self.health)
    end
    return
  end
  if not self.maxpkt then
    return
  end
  dev.pt=1.0
  self.pt=1.0
  dev.pkt=dev.pkt-v
  self.pkt=min(self.pkt+v,self.maxpkt)
  if dev.maxpkt then
    mput("Pr:%d:%d:%d:%d",dev.idx,self.idx,dev.pkt,self.pkt)
  else
    mput("Pr:%d:%d::%d",dev.idx,self.idx,self.pkt)
  end
end

function Vault:packet(dev,v)
  if self.deleted then
    return
  end
  local pl=self.pl
  dev.pt=1.0
  self.pt=1.0
  dev.pkt=dev.pkt-v
  pl.cash=min(pl.cash+v,pl.maxcash)
  mput("Pc:%d:%d:%d:%d",dev.idx,self.idx,pl.cash,dev.pkt)
end

function Vault:update(e,pl)
  if e=="delete" then
    if self.attch then
      local cash=floor(self.pl.cash/self.pl.vcnt)
      self.pl.vcnt=self.pl.vcnt-1
      self.pl.maxcash=self.pl.vcnt*VCASH
    else
      local cash=floor(self.pl.cash/(self.pl.vcnt+1))
      self.pl.cash=self.pl.cash-cash
    end
    cput("PC:%d:%d:%d",self.pl.idx,self.pl.cash,self.pl.maxcash)
    return
  end
  if e=="takeover" then
    if self.attch then
      local cash=floor(self.pl.cash/self.pl.vcnt)
      self.pl.cash=self.pl.cash-cash
      self.pl.vcnt=self.pl.vcnt-1
      self.pl.maxcash=self.pl.vcnt*VCASH
      pl.cash=pl.cash+cash
    else
      local cash=floor(self.pl.cash/(self.pl.vcnt+1))
      self.pl.cash=self.pl.cash-cash
      pl.cash=pl.cash+cash
    end
    cput("PC:%d:%d:%d",self.pl.idx,self.pl.cash,self.pl.maxcash)
    return
  end
  if e=="detach" then
    self.pl.vcnt=self.pl.vcnt-1
    self.pl.maxcash=self.pl.vcnt*VCASH
    self.attch=false
    cput("PC:%d:%d:%d",self.pl.idx,self.pl.cash,self.pl.maxcash)
    return
  end
  if e=="attach" then
    self.pl.vcnt=self.pl.vcnt+1
    self.pl.maxcash=self.pl.vcnt*VCASH
    self.attch=true
    cput("PC:%d:%d:%d",self.pl.idx,self.pl.cash,self.pl.maxcash)
    return
  end
end

function Generator:check(dt)
  if self.deleted then
    return
  end
  if not self.pl then
    return
  end
  self.dt2=self.dt2+dt
  if self.online and self.dt2>=DEGT then
    self.online=false
    cput("Ds:%d:%d",self.idx,0)
    return
  end
end

function Generator:signal(dev)
  if self.deleted then
    return
  end
  if self.pl==dev.pl then
    dev.pt=1.0
    self.pt=1.0
    self.dt2=0
    dev.pkt=dev.pkt-1
    mput("Ps:%d:%d:%d",dev.idx,self.idx,dev.pkt)
    return
  end
  self:takeover(dev.pl)
  cput("Po:%d:%d:%d",dev.idx,self.idx,dev.pkt)
end

function Power:logic()
  local i,d,l,c,e,v
  l=#self.links
  c=l
  e=self.ec
  i=self.li>l and 1 or self.li
  while c>0 and e>0 do
    d=self.links[i].dev2
    i=i<l and i+1 or 1
    if d.online then
      v=nil
      if d.health<d.maxhealth then
        v=self.pwr
      elseif d.maxpkt and d.pkt<d.maxpkt then
        v=self.pwr
      end
      if v then
        d:packet(self,v)
        e=e-1
      end
    end
    c=c-1
  end
  self.li=i
end

function Router:logic()
  if self.pkt<1 then
    return
  end
  local i,d,l,c,e,v
  l=#self.links
  c=l
  e=self.ec
  i=self.li>l and 1 or self.li
  while c>0 and e>0 do
    d=self.links[i].dev2
    i=i<l and i+1 or 1
    if d.online then
      v=nil
      if d.health<d.maxhealth then
        v=d.maxhealth-d.health
      elseif d.maxpkt and d.pkt<d.maxpkt then
        v=d.maxpkt and d.maxpkt-d.pkt or MAXV
      elseif d.cl=="V" then
        v=MAXV
      end
      if v then
        v=min(MAXV,self.pkt,v)
        d:packet(self,v)
        e=e-1
        if self.pkt<1 then
          break
        end
      end
    end
    c=c-1
  end
  self.li=i
end

function Signal:logic()
  if self.pkt<1 then
    return
  end
  local i,d,l,c,e
  l=#self.links
  c=l
  e=self.ec
  i=self.li>l and 1 or self.li
  while c>0 and e>0 do
    d=self.links[i].dev2
    i=i<l and i+1 or 1
    if d.signal then
      d:signal(self)
      e=e-1
      if self.pkt<1 then
        break
      end
    end
    c=c-1
  end
  self.li=i
end

function Tower:shot(targ)
  local tx,ty=targ.x-self.x,targ.y-self.y
  if sqrt(tx*tx+ty*ty)>=SHOTR then
    return
  end
  self.pt=1.0
  self.pkt=self.pkt-1
  targ.pt=1.0
  targ.health=targ.health-10
  if targ.health<1 then
    targ:delete()
    cput("Td:%d:%d:%d",self.idx,targ.idx,self.pkt)
    devices:del(targ)
  else
    mput("Th:%d:%d:%d:%d",self.idx,targ.idx,self.pkt,targ.health)
  end
end

function Tower:logic()
  if self.pl then
    return
  end
  if self.pkt<1 then
    return
  end
  local t=hash:get(self.x-SHOTR,self.y-SHOTR,self.x+SHOTR,self.y+SHOTR)
  local targ
  local tlen=SHOTR
  local tx,ty,len
  local e=self.ec
  for _,o in pairs(t) do
    if o.pl~=self.pl and o.initok and o.cl~="G" then
      tx,ty=o.x-self.x,o.y-self.y
      len=sqrt(tx*tx+ty*ty)
      if len<tlen then
        targ=o
        tlen=len
      end
    end
  end
  if targ then
    self:shot(targ)
  end
end
