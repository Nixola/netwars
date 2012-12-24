-- vim:et

NVER="master 9" -- network protocol version

VCASH=3000 -- vault cash storage
MAXV=10 -- max pkt value
LINK=300 -- max link dinstance
LINK2=LINK+2
DEGT=10 -- degrate timer
SHOTR=250 -- shot length

class "Player"

function Player:initialize(cash)
  self.cash=cash
  self.maxcash=0
  self.pkts=0
  self.devcnt=0
  self.vcnt=0
end

function Player:disconnect()
  if packets then
    for _,p in pairs(packets) do
      if p.dev1.pl==self or p.dev2.pl==self then
        p:delete()
        packets:del(p)
      end
    end
  end
  for k,o in pairs(devices) do
    if o.pl==self then
      o:del_links()
      devices[k]=nil
      hash:del(o)
      o.deleted=true
    end
  end
end

class "Device" {
r=15;
cr=30; -- collision radius
}

function Device:initialize(pl,x,y)
  self.pl=pl
  self.x=x
  self.y=y
  self.online=false
  self.initok=false
  self.isdev=true
  self.li=1 -- link index, used to forward packets (cyclic)
  self.dt=0 -- dt for logic
  self.dt2=0 -- dt for degradation
  self.pt=0 -- dt for packet on wire (server side)
  self.pc=0 -- packet cnt on wire (client side)
  self.pkt=0 -- packets in queue
  self.targ=nil -- manual target (device)
  self.lupd=false -- link update
  self.gotpwr=false -- connected to base
  self.attch=false -- D attached to base
  self.nomove=false
  self.bdevs={} -- devices connected to us (back links)
  if self.cl=="G" then
    self.initok=true
    self.nomove=true
    self.pwr=0
    self.online=true
  end
  if self.cl=="B" then
    self.initok=true
    self.gotpwr=true
    self.pwr=10
  end
  self.health=self.maxhealth
  self.links={} -- forward links
  self.blinks={} -- back links
  if pl then
    pl.devcnt=pl.devcnt+1
  end
end

function Device:bound_box(_x,_y)
  local x=_x or self.x
  local y=_y or self.y
  return x-self.cr,y-self.cr,x+self.cr,y+self.cr
end

function Device:calc_xy(x,y)
  local d,len,s
  local vx,vy
  for _,l in pairs(self.links) do
    d=l.dev1==self and l.dev2 or l.dev1
    vx,vy=x-d.x,y-d.y
    len=floor(sqrt(vx*vx+vy*vy))
    if len>LINK then
      s=(len-LINK)/len
      vx,vy=vx*s,vy*s
      x,y=x-vx,y-vy
    end
  end
  for _,l in pairs(self.blinks) do
    d=l.dev1==self and l.dev2 or l.dev1
    vx,vy=x-d.x,y-d.y
    len=floor(sqrt(vx*vx+vy*vy))
    if len>LINK then
      s=(len-LINK)/len
      vx,vy=vx*s,vy*s
      x,y=x-vx,y-vy
    end
  end
  x,y=floor(x),floor(y)
  return x,y
end

function Device:chk_border(x,y)
  local t=hash:get(self:bound_box(x,y))
  local ok=true
  local len,vx,vy
  local br
  for _,d in pairs(t) do
    if self~=d then
      vx,vy=x-d.x,y-d.y
      len=floor(sqrt(vx*vx+vy*vy))
      br=d.cr
      if len<=br*2 then
        ok=false
        break
      end
    end
  end
  return ok
end

function Device:move(x,y)
  if self.nomove then
    return false
  end
  x,y=self:calc_xy(x,y)
  if self:chk_border(x,y) then
    hash:del(self)
    self.x=x
    self.y=y
    hash:add(self)
    return true
  end
  return false
end

function Device:connect(dev)
  if not self.initok then
    return nil
  end
  if self==dev then
    return nil
  end
  if self.cl=="B" and dev.cl~="R" then
    return nil
  end
  if self.cl=="G" and dev.cl~="R" then
    return nil
  end
  if #self.links>=self.maxlinks then
    return nil
  end
  if #dev.blinks>=dev.maxblinks then
    return nil
  end
  local tx,ty=self.x-dev.x,self.y-dev.y
  local len=floor(sqrt(tx*tx+ty*ty))
  if len>LINK2 then
    return nil
  end
  local ok=true
  for _,l in ipairs(self.links) do
    if l.dev2==dev then
      ok=false
      break
    end
  end
  if ok then
    local l=Link:new(self,dev)
    table.insert(self.links,l)
    table.insert(dev.blinks,l)
    dev.lupd=true
    self.initok=true
    dev.initok=true
    return l
  end
  return nil
end

function Device:unlink(dev)
  for _,l in ipairs(self.links) do
    if l.dev2==dev then
      self:del_link(dev)
      dev:del_blink(self)
      return l
    end
  end
  return nil
end

function Device:del_link(dev)
  for i,l in ipairs(self.links) do
    if l.dev2==dev then
      table.remove(self.links,i)
      return
    end
  end
end

function Device:del_blink(dev)
  for i,l in ipairs(self.blinks) do
    if l.dev1==dev then
      table.remove(self.blinks,i)
      self.lupd=true
      return
    end
  end
end

function Device:del_links()
  local tmp={}
  for _,l in ipairs(self.links) do
    if l.dev1==self then
      tmp[#tmp+1]=l
    end
  end
  for _,l in pairs(tmp) do
    self:del_link(l.dev2)
    l.dev2:del_blink(self)
    links:del(l)
  end
  tmp={}
  for _,l in ipairs(self.blinks) do
    if l.dev2==self then
      tmp[#tmp+1]=l
    end
  end
  for _,l in pairs(tmp) do
    self:del_blink(l.dev1)
    l.dev1:del_link(self)
    links:del(l)
  end
end

function Device:takeover(pl)
  if self.pl then
    self.pl.devcnt=self.pl.devcnt-1
  end
  self.pl=pl
  self.online=false
  if pl then
    pl.devcnt=pl.devcnt+1
    if SRV and self.cl=="V" then
      self:update("takeover",pl)
    end
  end
end

function Device:delete()
  self:del_links()
  if self.pl then
    self.pl.devcnt=self.pl.devcnt-1
    if SRV and self.cl=="V" then
      self:update("delete")
    end
  end
  hash:del(self)
  self.deleted=true
end

class "Link"

function Link:initialize(d1,d2)
  self.dev1=d1
  self.dev2=d2
end

class "Power" : extends(Device) {
ec=1; -- emit count
em=1; -- max emit count
}

class "Base" : extends(Power) {
cl="B";
maxhealth=200;
maxlinks=3;
maxblinks=2;
price=0;
}

class "Generator" : extends(Power) {
cl="G";
maxhealth=100;
maxlinks=3;
maxblinks=2;
price=0;
}

class "Router" : extends(Device) {
cl="R";
ec=1; -- emit count
em=3; -- max emit count
maxhealth=50;
maxpkt=1000; -- max queue
maxlinks=6;
maxblinks=6;
price=100;
}

class "Vault" : extends(Device) {
cl="V";
maxhealth=100;
maxlinks=0;
maxblinks=3;
price=300;
}

class "Tower" : extends(Device) {
cl="T";
maxhealth=100;
maxpkt=100; -- max queue
maxlinks=0;
maxblinks=2;
price=300;
}

d_cl={B=Base,G=Generator,R=Router,V=Vault,T=Tower}
