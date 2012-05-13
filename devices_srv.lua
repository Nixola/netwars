-- vim:et

function Device:link(dev) -- use only in map generators
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
  if not self.maxpkt then
    return
  end
  dev.pt=1.0
  self.pt=1.0
  dev.pkt=dev.pkt-v
  self.pkt=self.pkt+v
  if self.pkt>self.maxpkt then
    self.pkt=self.maxpkt
  end
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
  pl.cash=pl.cash+v
  if pl.cash>pl.maxcash then
    pl.cash=pl.maxcash
  end
  mput("Pc:%d:%d:%d:%d",dev.idx,self.idx,pl.cash,dev.pkt)
end

function Vault:update(e,pl)
  if e=="delete" then
    if self.attch then
      local cash=math.floor(self.pl.cash/self.pl.dcnt)
      self.pl.dcnt=self.pl.dcnt-1
      self.pl.maxcash=self.pl.dcnt*VCASH
    else
      local cash=math.floor(self.pl.cash/(self.pl.dcnt+1))
      self.pl.cash=self.pl.cash-cash
    end
    cput("PC:%d:%d:%d",self.pl.idx,self.pl.cash,self.pl.maxcash)
    return
  end
  if e=="takeover" then
    if self.attch then
      local cash=math.floor(self.pl.cash/self.pl.dcnt)
      self.pl.cash=self.pl.cash-cash
      self.pl.dcnt=self.pl.dcnt-1
      self.pl.maxcash=self.pl.dcnt*VCASH
      pl.cash=pl.cash+cash
    else
      local cash=math.floor(self.pl.cash/(self.pl.dcnt+1))
      self.pl.cash=self.pl.cash-cash
      pl.cash=pl.cash+cash
    end
    cput("PC:%d:%d:%d",self.pl.idx,self.pl.cash,self.pl.maxcash)
    return
  end
  if e=="detach" then
    self.pl.dcnt=self.pl.dcnt-1
    self.pl.maxcash=self.pl.dcnt*VCASH
    self.attch=false
    cput("PC:%d:%d:%d",self.pl.idx,self.pl.cash,self.pl.maxcash)
    return
  end
  if e=="attach" then
    self.pl.dcnt=self.pl.dcnt+1
    self.pl.maxcash=self.pl.dcnt*VCASH
    self.attch=true
    cput("PC:%d:%d:%d",self.pl.idx,self.pl.cash,self.pl.maxcash)
    return
  end
end

function Generator:logic()
  local i,d,p,l,c,e,v
  l=#self.links
  c=l
  e=self.ec
  i=self.li>l and 1 or self.li
  while c>0 and e>0 do
    d=self.links[i].dev2
    i=i<l and i+1 or 1
    if d.online and (not d.maxpkt or d.pkt<d.maxpkt) then
      v=self.pwr
      d:packet(self,v)
      e=e-1
    end
    c=c-1
  end
  self.li=i
end

function Router:logic()
  if self.pkt<1 then
    return
  end
  local i,d,p,l,c,e,v
  l=#self.links
  c=l
  e=self.ec
  i=self.li>l and 1 or self.li
  while c>0 and e>0 do
    d=self.links[i].dev2
    i=i<l and i+1 or 1
    if d.online and (not d.maxpkt or d.pkt<d.maxpkt) then
      v=self.pkt>MAXV and MAXV or self.pkt
      d:packet(self,v)
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
  if math.sqrt(tx*tx+ty*ty)>=SHOTR then
    return
  end
  if targ.isdev then
    self.pkt=self.pkt-1
    targ.health=targ.health-5
    targ.pt=1.0
    if targ.health<1 then
      targ:delete()
      cput("TD:%d:%d:%d",self.idx,targ.idx,self.pkt)
      devices:del(targ)
    else
      mput("TH:%d:%d:%d:%d",self.idx,targ.idx,self.pkt,targ.health)
    end
  else
    self.pkt=self.pkt-1
    targ.health=targ.health-5
    if targ.health<1 then
      targ:delete()
      cput("Td:%d:%d:%d",self.idx,targ.idx,self.pkt)
      units:del(targ)
    else
      mput("Th:%d:%d:%d:%d",self.idx,targ.idx,self.pkt,targ.health)
    end
  end
end

function Tower:logic()
  if self.pl then
    return
  end
  if self.pkt<1 then
    return
  end
  local t=uhash:get(self.x-SHOTR,self.y-SHOTR,self.x+SHOTR,self.y+SHOTR)
  local targ
  local tlen=SHOTR
  local tx,ty,len
  local e=self.ec
  for _,u in pairs(t) do
    if u.pl~=self.pl then
      tx,ty=u.x-self.x,u.y-self.y
      len=math.sqrt(tx*tx+ty*ty)
      if len<tlen then
        targ=u
        tlen=len
      end
    end
  end
  if targ then
    self:shot(targ)
  end
end

function SupplyBay:transfer(targ)
  local tx,ty=targ.x-self.x,targ.y-self.y
  if math.sqrt(tx*tx+ty*ty)>=SUPPR then
    return
  end
  if targ.pkt<targ.maxpkt then
    local v=self.pkt>MAXV and MAXV or self.pkt
    self.pkt=self.pkt-v
    targ.pkt=targ.pkt+v
    if targ.pkt>targ.maxpkt then
      targ.pkt=targ.maxpkt
    end
  end
  mput("SP:%d:%d:%d:%d",self.idx,targ.idx,self.pkt,targ.pkt)
end

Factory.transfer=SupplyBay.transfer

function Commander:capture(targ)
  if targ.pl==self.pl then
    return
  end
  local tx,ty=targ.x-self.x,targ.y-self.y
  if math.sqrt(tx*tx+ty*ty)>=BEAMR then
    return
  end
  if targ.cpl~=self.pl then
    targ.cpl=self.pl
    targ.ccnt=0
  end
  targ.ccnt=targ.ccnt+1
  if targ.ccnt<CAPTC then
    mput("SC:%d:%d:%d",self.idx,targ.idx,self.pkt)
    return
  end
  cput("SO:%d:%d:%d",self.idx,targ.idx,self.pkt)
  targ:takeover(self.pl)
  self.targ=nil
end

function Commander:shot(targ)
  local tx,ty=targ.x-self.x,targ.y-self.y
  if math.sqrt(tx*tx+ty*ty)>=SHOTR then
    return
  end
  targ.health=targ.health-10
  if targ.health<1 then
    targ:delete()
    cput("Sd:%d:%d:%d",self.idx,targ.idx,self.pkt)
    units:del(targ)
  else
    mput("Sh:%d:%d:%d:%d",self.idx,targ.idx,self.pkt,targ.health)
  end
end

function Engineer:shot(targ)
  local tx,ty=targ.x-self.x,targ.y-self.y
  if math.sqrt(tx*tx+ty*ty)>=BEAMR then
    return
  end
  if targ.isdev then
    if targ.health<targ.maxhealth then
      local v=self.pkt>MAXV and MAXV or self.pkt
      self.pkt=self.pkt-v
      targ.health=targ.health+v*2
      targ.pt=1.0
      if targ.health>targ.maxhealth then
        targ.health=targ.maxhealth
      end
    end
    mput("SH:%d:%d:%d:%d",self.idx,targ.idx,self.pkt,targ.health)
  else
    if targ.health<targ.maxhealth then
      local v=self.pkt>MAXV and MAXV or self.pkt
      self.pkt=self.pkt-v
      targ.health=targ.health+v*2
      if targ.health>targ.maxhealth then
        targ.health=targ.maxhealth
      end
    end
    mput("Sh:%d:%d:%d:%d",self.idx,targ.idx,self.pkt,targ.health)
  end
end

function Engineer:capture(targ)
  if targ.pl==self.pl then
    return
  end
  if self.pkt<MAXV then
    return
  end
  local tx,ty=targ.x-self.x,targ.y-self.y
  if math.sqrt(tx*tx+ty*ty)>=BEAMR then
    return
  end
  self.pkt=self.pkt-MAXV
  if targ.cpl~=self.pl then
    targ.cpl=self.pl
    targ.ccnt=0
  end
  targ.ccnt=targ.ccnt+1
  targ.pt=1.0
  if targ.ccnt<CAPTC then
    mput("SC:%d:%d:%d",self.idx,targ.idx,self.pkt)
    return
  end
  cput("SO:%d:%d:%d",self.idx,targ.idx,self.pkt)
  targ:takeover(self.pl)
  self.targ=nil
end


function Tank:shot(targ)
  local tx,ty=targ.x-self.x,targ.y-self.y
  if math.sqrt(tx*tx+ty*ty)>=SHOTR then
    return
  end
  if targ.isdev then
    self.pkt=self.pkt-1
    targ.health=targ.health-5
    targ.pt=1.0
    if targ.health<1 then
      targ:delete()
      cput("SD:%d:%d:%d",self.idx,targ.idx,self.pkt)
      devices:del(targ)
      self.targ=nil
    else
      mput("SH:%d:%d:%d:%d",self.idx,targ.idx,self.pkt,targ.health)
    end
  else
    self.pkt=self.pkt-1
    targ.health=targ.health-5
    if targ.health<1 then
      targ:delete()
      cput("Sd:%d:%d:%d",self.idx,targ.idx,self.pkt)
      units:del(targ)
    else
      mput("Sh:%d:%d:%d:%d",self.idx,targ.idx,self.pkt,targ.health)
    end
  end
end

function Supply:transfer(targ)
  local tx,ty=targ.x-self.x,targ.y-self.y
  if math.sqrt(tx*tx+ty*ty)>=BEAMR then
    return
  end
  if targ.pkt<targ.maxpkt then
    local v=self.pkt>MAXV and MAXV or self.pkt
    self.pkt=self.pkt-v
    targ.pkt=targ.pkt+v
    if targ.pkt>targ.maxpkt then
      targ.pkt=targ.maxpkt
    end
  end
  mput("Sp:%d:%d:%d:%d",self.idx,targ.idx,self.pkt,targ.pkt)
end
