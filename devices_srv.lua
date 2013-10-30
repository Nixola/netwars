-- vim:et

function Device:link(dev) -- use only in map generators
  self.initok=true
  local l=self:connect(dev)
  if l then
    links:add(l)
  end
end

function Device:f_path()
  if self.cl=="R" and next(self.ldevs) then
    local ok=self.gotpwr
    local chk={}
    local tmp=self.ldevs
    local tmp2={}
    chk[self]=self
    while next(tmp) do
      for _,d in pairs(tmp) do
        if not chk[d] and not d.nochk and d.gotpwr~=ok then
          chk[d]=d
          if not ok and count(d.bdevs)>1 then
            d.lupd=true
          else
            d.gotpwr=ok
            if ok then
              d.lupd=false
            end
            if d.cl=="R" then
              for _,o in pairs(d.ldevs) do
                tmp2[o]=o
              end
            end
          end
        end
      end
      tmp=tmp2
      tmp2={}
    end
  end
end

function Device:chk_devs()
  local k=self.pl and "base" or "pwr"
  local chk={}
  local ok=false
  local tmp=self.bdevs
  local tmp2={}
  chk[self]=self
  while next(tmp) do
    for _,d in pairs(tmp) do
      if not chk[d] and d.gotpwr then
        if d[k] then
          ok=true
          break
        end
        chk[d]=d
        if not d.nochk then
          for _,o in pairs(d.bdevs) do
            tmp2[o]=o
          end
        end
      end
    end
    if ok then
      break
    end
    tmp=tmp2
    tmp2={}
  end
  if self.gotpwr==ok then
    return false
  end
  self.gotpwr=ok
  return true
end

function Device:check()
  if self.deleted then
    return
  end
  if not self.initok then
    return
  end
  if self.nochk then
    return
  end
  if self.lupd and self:chk_devs() then
    self:f_path()
  end
  local ok=self.gotpwr
  if not ok and self.online then
    self.online=false
    cput("Ds:%d:0",self.idx)
  end
  if self.cl=="V" then
    if not ok and self.attch then
      self:update("detach")
    end
    if ok and not self.attch then
      self:update("attach")
    end
  end
end

function Device:heal(dev,v)
  self.health=min(self.health+v,self.maxhealth)
  dev.pt=1.0
  self.pt=1.0
  if dev.maxpkt then
    dev.pkt=dev.pkt-v
    mput("Ph:%d:%d:%d:%d",dev.idx,self.idx,dev.pkt,self.health)
  else
    mput("Ph:%d:%d::%d",dev.idx,self.idx,self.health)
  end
end

function Device:packet(dev,v)
  if self.deleted then
    return
  end
  if self.health<self.maxhealth then
    self:heal(dev,v)
    return
  end
  if not self.maxpkt then
    return
  end
  self.pkt=min(self.pkt+v,self.maxpkt)
  dev.pt=1.0
  self.pt=1.0
  if dev.maxpkt then
    dev.pkt=dev.pkt-v
    mput("Pr:%d:%d:%d:%d",dev.idx,self.idx,dev.pkt,self.pkt)
  else
    mput("Pr:%d:%d::%d",dev.idx,self.idx,self.pkt)
  end
end

function Vault:packet(dev,v)
  if self.deleted then
    return
  end
  if self.health<self.maxhealth then
    self:heal(dev,v)
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
      self.pl.vcnt=self.pl.vcnt-1
      self.pl.maxcash=self.pl.vcnt*VCASH
      self.pl.cash=min(self.pl.cash,self.pl.maxcash)
      cput("PC:%d:%d:%d",self.pl.idx,self.pl.cash,self.pl.maxcash)
    end
    return
  end
  if e=="detach" then
    self.pl.vcnt=self.pl.vcnt-1
    self.pl.maxcash=self.pl.vcnt*VCASH
    self.pl.cash=min(self.pl.cash,self.pl.maxcash)
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

function Router:chk_units()
  local t=uhash:get(self.x-SHOTR,self.y-SHOTR,self.x+SHOTR,self.y+SHOTR)
  local tx,ty,len,v
  local ok=false
  for _,u in pairs(t) do
    if u.pl==self.pl then
      tx,ty=u.x-self.x,u.y-self.y
      len=sqrt(tx*tx+ty*ty)
      if len<SHOTR then
        v=nil
        if u.health<u.maxhealth then
          v=u.maxhealth-u.health
        elseif u.maxpkt and u.pkt<u.maxpkt then
          v=u.maxpkt-u.pkt
        end
        if v then
          v=min(MAXH,self.pkt,v)
          u:packet(self,v)
          ok=true
        end
      end
    end
    if self.pkt<1 then
      break
    end
  end
  return ok
end

function Router:logic()
  if self.pkt<1 then
    return
  end
  if self:chk_units() then
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
        v=min(MAXH,self.pkt,v)
      elseif d.maxpkt and d.pkt<d.maxpkt then
        v=d.maxpkt-d.pkt
        if d.cl=="T" then
          v=min(MAXH,self.pkt,v)
        else
          v=min(MAXV,self.pkt,v)
        end
      elseif d.cl=="V" then
        v=min(MAXV,self.pkt)
      end
      if v then
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

function Tower:shot(targ)
  local tx,ty=targ.x-self.x,targ.y-self.y
  if targ.deleted or sqrt(tx*tx+ty*ty)>SHOTT then
    return
  end
  self.pt=1.0
  self.pkt=self.pkt-3
  targ.health=targ.health-10
  if targ.isdev then
    targ.pt=1.0
    if targ.health<1 then
      targ:delete()
      cput("TD:%d:%d:%d",self.idx,targ.idx,self.pkt)
      devices:del(targ)
    else
      mput("TH:%d:%d:%d:%d",self.idx,targ.idx,self.pkt,targ.health)
    end
    return
  end
  if targ.health<1 then
    targ:delete()
    cput("Td:%d:%d:%d",self.idx,targ.idx,self.pkt)
    units:del(targ)
  else
    mput("Th:%d:%d:%d:%d",self.idx,targ.idx,self.pkt,targ.health)
  end
end

function Tower:logic()
  if self.pkt<3 then
    return
  end
  local t=uhash:get(self.x-SHOTT,self.y-SHOTT,self.x+SHOTT,self.y+SHOTT)
  local targ=nil
  local tlen=SHOTT
  local tx,ty,len
  for _,u in pairs(t) do
    if u.pl~=self.pl then
      tx,ty=u.x-self.x,u.y-self.y
      len=sqrt(tx*tx+ty*ty)
      if len<tlen then
        targ=u
        tlen=len
      end
    end
  end
  if targ then
    self:shot(targ)
    return
  end
  t=dhash:get(self.x-SHOTT,self.y-SHOTT,self.x+SHOTT,self.y+SHOTT)
  targ=nil
  tlen=SHOTT
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

function Unit:heal(dev,v)
  self.health=min(self.health+v,self.maxhealth)
  dev.pt=1.0
  self.pt=1.0
  if dev.maxpkt then
    dev.pkt=dev.pkt-v
    mput("Pu:%d:%d:%d:%d",dev.idx,self.idx,dev.pkt,self.health)
  else
    mput("Pu:%d:%d::%d",dev.idx,self.idx,self.health)
  end
end

function Unit:packet(dev,v)
  if self.deleted then
    return
  end
  if self.health<self.maxhealth then
    self:heal(dev,v)
    return
  end
  if not self.maxpkt then
    return
  end
  self.pkt=min(self.pkt+v,self.maxpkt)
  dev.pt=1.0
  if dev.maxpkt then
    dev.pkt=dev.pkt-v
    mput("Ps:%d:%d:%d:%d",dev.idx,self.idx,dev.pkt,self.pkt)
  else
    mput("Ps:%d:%d::%d",dev.idx,self.idx,self.pkt)
  end
end

function Tank:shot(targ)
  local tx,ty=targ.x-self.x,targ.y-self.y
  if targ.deleted or sqrt(tx*tx+ty*ty)>SHOTR then
    return
  end
  self.blocked=false
  self.pkt=self.pkt-(self.uc*3)
  targ.health=targ.health-(self.uc*10)
  if targ.isdev then
    targ.pt=1.0
    if targ.health<1 then
      targ:delete()
      cput("SD:%d:%d:%d",self.idx,targ.idx,self.pkt)
      devices:del(targ)
    else
      mput("SH:%d:%d:%d:%d",self.idx,targ.idx,self.pkt,targ.health)
    end
    return
  end
  if targ.health<1 then
    targ:delete()
    cput("Sd:%d:%d:%d",self.idx,targ.idx,self.pkt)
    units:del(targ)
  else
    mput("Sh:%d:%d:%d:%d",self.idx,targ.idx,self.pkt,targ.health)
  end
end

function Tank:logic()
  if self.pkt<self.uc*3 then
    if not self.blocked then
      self.blocked=true
      cput("Sb:%d:1",self.idx)
    end
    return
  end
  local cr=Tank.r*2
  local t=uhash:get(self.x-SHOTR,self.y-SHOTR,self.x+SHOTR,self.y+SHOTR)
  local a=ally[self.pl]
  local targ=nil
  local tlen=SHOTR
  local tx,ty,len
  for _,u in pairs(t) do
    tx,ty=u.x-self.x,u.y-self.y
    len=sqrt(tx*tx+ty*ty)
    if u.pl~=self.pl and not a[u.pl] then
      if len<tlen then
        targ=u
        tlen=len
      end
    else
      if u~=self and len<=cr then
        if not self.blocked then
          self.blocked=true
          cput("Sb:%d:1",self.idx)
        end
        return
      end
    end
  end
  if targ then
    self:shot(targ)
    return
  end
  t=dhash:get(self.x-SHOTR,self.y-SHOTR,self.x+SHOTR,self.y+SHOTR)
  targ=nil
  tlen=SHOTR
  for _,o in pairs(t) do
    if o.pl~=self.pl and o.initok and o.cl~="G" and not a[o.pl] then
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
    return
  end
  if self.blocked then
    self.blocked=false
    cput("Sb:%d:0",self.idx)
  end
end
