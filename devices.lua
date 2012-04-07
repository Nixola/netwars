-- vim:et

NVER=5 -- network protocol version
MAXP=1000 -- max pkt queue
MAXV=10 -- max pkt value
LINK=300 -- max link dinstance
LINK2=LINK+2
DEGT=10 -- degrate timer
DEGV=10 -- degrate health value

vec={}
function vec.len(x1,y1,x2,y2)
  local tx,ty=x2-x1,y2-y1
  return math.sqrt(tx*tx+ty*ty)
end

class "Player"

function Player:initialize(cash)
  self.cash=cash
  self.maxcash=0
  self.pkts=0
  self.devcnt=0
  self.dcnt=0
end

function Player:disconnect()
  for _,p in pairs(packets) do
    if p.dev1.pl==self or p.dev2.pl==self then
      p.dev1.pc=p.dev1.pc-1
      p.dev2.pc=p.dev2.pc-1
      packets:del(p)
      if p.pl==ME then
        ME.pkts=ME.pkts-1
      end
    end
  end
  for k,o in pairs(devices) do
    if o.pl==self then
      o:del_links()
      if o.cl=="G" then
        o.pl=nil
        o.health=o.maxhealth
        o.online=false
      else
        devices[k]=nil
        devhash:del(o)
      end
    end
  end
end

class "Device" {
r=15;
cr=30; -- collision radius
er=100; -- enemy border radius
}

function Device:initialize(pl,x,y)
  self.pl=pl
  self.x=x
  self.y=y
  self.online=false
  self.li=1 -- link index, used to forward packets (cyclic)
  self.dt=0 -- dt for packet forward
  self.dt2=0 -- dt for degradation
  self.pc=0 -- packet cnt on wire
  self.pkt=0 -- packets in queue
  self.pupd=false -- update packet info
  self.lupd=false -- link update
  self.gotpwr=false -- connected to power source (G or B)
  self.attch=false -- D attached to power source
  self.nomove=false
  self.bdevs={} -- devices connected to us (back links)
  if self.cl=="B" then
    self.pwr=0
    self.gotpwr=true
  end
  if self.cl=="G" then
    self.nomove=true
    self.pwr=0
    self.gotpwr=true
  end
  self.health=self.maxhealth
  self.links={} -- forward links
  self.blinks={} -- back links
  self.elinks={} -- enemy connections
  if pl then
    pl.devcnt=pl.devcnt+1
  end
end

function Device:bound_box(_x,_y)
  local x=_x or self.x
  local y=_y or self.y
  return x-self.er,y-self.er,x+self.er,y+self.er
end

function Device:calc_xy(x,y)
  local d,len,s
  local vx,vy
  for _,l in pairs(self.links) do
    d=l.dev1==self and l.dev2 or l.dev1
    vx,vy=x-d.x,y-d.y
    len=math.sqrt(vx*vx+vy*vy)
    if len>LINK then
      s=(len-LINK)/len
      vx,vy=vx*s,vy*s
      x,y=x-vx,y-vy
    end
  end
  for _,l in pairs(self.blinks) do
    d=l.dev1==self and l.dev2 or l.dev1
    vx,vy=x-d.x,y-d.y
    len=math.sqrt(vx*vx+vy*vy)
    if len>LINK then
      s=(len-LINK)/len
      vx,vy=vx*s,vy*s
      x,y=x-vx,y-vy
    end
  end
  for _,l in pairs(self.elinks) do
    d=l.dev1==self and l.dev2 or l.dev1
    vx,vy=x-d.x,y-d.y
    len=math.sqrt(vx*vx+vy*vy)
    if len>LINK then
      s=(len-LINK)/len
      vx,vy=vx*s,vy*s
      x,y=x-vx,y-vy
    end
  end
  return x,y
end

function Device:chk_border(x,y)
  local t=devhash:get(self:bound_box(x,y))
  local ok=true
  local len,vx,vy
  local br
  for _,d in pairs(t) do
    if self~=d then
      vx,vy=x-d.x,y-d.y
      len=math.sqrt(vx*vx+vy*vy)
      br=self.pl==d.pl and d.cr or d.er
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
    devhash:del(self)
    self.x=x
    self.y=y
    devhash:add(self)
    return true
  end
  return false
end

function Device:upd_bdevs()
  local tmp={}
  for _,l in ipairs(self.blinks) do
    if l.dev2==self then
      tmp[#tmp+1]=l.dev1
    end
  end
  self.bdevs=tmp
end

function Device:connect(dev)
  if self==dev then
    return nil
  end
  if self.cl=="G" and dev.cl~="R" then
    return nil
  end
  if self.cl=="B" and dev.cl~="R" then
    return nil
  end
  if #self.links>=self.maxlinks then
    return nil
  end
  if self.pl==dev.pl then
    if #dev.blinks>=dev.maxblinks then
      return nil
    end
  else
    if #dev.elinks>=dev.maxblinks then
      return nil
    end
  end
  if vec.len(self.x,self.y,dev.x,dev.y)>LINK2 then
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
    if self.pl==dev.pl then
      table.insert(dev.blinks,l)
      dev.lupd=true
    else
      table.insert(dev.elinks,l)
    end
    return l
  end
  return nil
end

function Device:unlink(dev)
  for _,l in ipairs(self.links) do
    if l.dev2==dev then
      self:del_link(l.dev2)
      if self.pl==dev.pl then
        dev:del_blink(self)
        dev.lupd=true
      else
        dev:del_elink(self)
      end
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
      return
    end
  end
end

function Device:del_elink(dev)
  for i,l in ipairs(self.elinks) do
    if l.dev1==dev then
      table.remove(self.elinks,i)
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
    if self.pl==l.dev2.pl then
      l.dev2:del_blink(self)
    else
      l.dev2:del_elink(self)
    end
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
  tmp={}
  for _,l in ipairs(self.elinks) do
    if l.dev2==self then
      tmp[#tmp+1]=l
    end
  end
  for _,l in pairs(tmp) do
    self:del_elink(l.dev1)
    l.dev1:del_link(self)
    links:del(l)
  end
end

function Device:del_packets()
  for _,p in pairs(packets) do
    if p.dev1==self or p.dev2==self then
      p.dev1.pc=p.dev1.pc-1
      p.dev2.pc=p.dev2.pc-1
      packets:del(p)
      if p.pl==ME then
        ME.pkts=ME.pkts-1
      end
    end
  end
end

function Device:delete()
  for _,p in pairs(packets) do
    if p.dev1==self or p.dev2==self then
      p.dev1.pc=p.dev1.pc-1
      p.dev2.pc=p.dev2.pc-1
      packets:del(p)
      if p.pl==ME then
        ME.pkts=ME.pkts-1
      end
    end
  end
  self:del_links()
  if self.pl then
    self.pl.devcnt=self.pl.devcnt-1
    if SRV and self.cl=="D" then
      if self.attch then
        self.pl.cash=self.pl.cash-math.floor(self.pl.cash/self.pl.dcnt)
        self.pl.dcnt=self.pl.dcnt-1
        self.pl.maxcash=self.pl.dcnt*1000
      else
        self.pl.cash=self.pl.cash-math.floor(self.pl.cash/(self.pl.dcnt+1))
      end
    end
  end
  devhash:del(self)
  self.deleted=true
end

class "Link"

function Link:initialize(d1,d2)
  self.dev1=d1
  self.dev2=d2
end

function Link:del_packets()
  local d1=self.dev1
  local d2=self.dev2
  for _,p in pairs(packets) do
    if p.dev1==d1 and p.dev2==d2 then
      d1.pc=d1.pc-1
      d2.pc=d2.pc-1
      packets:del(p)
      if p.pl==ME then
        ME.pkts=ME.pkts-1
      end
    end
  end
end

class "Packet" {
r=3;
}

function Packet:initialize(d1,d2,v)
  local vx,vy=d2.x-d1.x,d2.y-d1.y
  local l=math.sqrt(vx*vx+vy*vy)
  self.dev1=d1
  self.dev2=d2
  if d1.cl=="F" and d2.pl then
    self.pl=d2.pl
  else
    self.pl=d1.pl
  end
  self.v=v
  d1.pc=d1.pc+1
  d2.pc=d2.pc+1
  vx,vy=vx/l,vy/l
  self.x=d1.x+vx*d1.r
  self.y=d1.y+vy*d1.r
  self.vx=vx*50
  self.vy=vy*50
  if self.pl==ME then
    ME.pkts=ME.pkts+1
  end
end

function Packet:flow(dt)
  local d1=self.dev1
  local d2=self.dev2
  self.x=self.x+self.vx*dt
  self.y=self.y+self.vy*dt
  local tx,ty=d2.x-self.x,d2.y-self.y
  local r=math.sqrt(tx*tx+ty*ty)
  if r<=d2.r then
    d1.pc=d1.pc-1
    d2.pc=d2.pc-1
    if self.pl==ME then
      ME.pkts=ME.pkts-1
    end
    return true
  end
  return false
end

class "Generator" : extends(Device) {
cl="G";
maxhealth=200;
maxlinks=3;
maxblinks=2;
price=0;
}

class "Router" : extends(Device) {
cl="R";
maxhealth=200;
maxlinks=5;
maxblinks=5;
price=50;
}

class "Friend" : extends(Router) {
cl="F";
maxhealth=100;
maxlinks=2;
maxblinks=3;
price=250;
}

class "DataCenter" : extends(Device) {
cl="D";
maxhealth=100;
maxlinks=0;
maxblinks=5;
price=200;
}

class "DataBase" : extends(Device) {
cl="B";
maxhealth=300;
maxlinks=3;
maxblinks=2;
price=300;
}

devcl={G=Generator,R=Router,F=Friend,D=DataCenter,B=DataBase}
