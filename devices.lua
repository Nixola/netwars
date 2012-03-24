-- vim:et

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
      devices[k]=nil
    end
  end
end

class "Device"

function Device:initialize(pl,x,y)
  self.pl=pl
  self.x=x
  self.y=y
  self.online=false
  self.li=1
  self.dt=0
  self.pc=0
  self.pkt=0
  self.off=0
  self.health=self.maxhealth
  self.links={}
  self.blinks={}
  self.elinks={}
  if pl then
    pl.devcnt=pl.devcnt+1
    if self.cl=="D" then
      pl.dcnt=pl.dcnt+1
      pl.maxcash=pl.dcnt*1000
    end
  end
end

function Device:calc_xy(x,y)
  local d,len,s
  local vx,vy
  for _,l in pairs(self.links) do
    d=l.dev1==self and l.dev2 or l.dev1
    vx,vy=x-d.x,y-d.y
    len=math.sqrt(vx*vx+vy*vy)
    if len>250 then
      s=(len-250)/len
      vx,vy=vx*s,vy*s
      x,y=x-vx,y-vy
    end
  end
  for _,l in pairs(self.blinks) do
    d=l.dev1==self and l.dev2 or l.dev1
    vx,vy=x-d.x,y-d.y
    len=math.sqrt(vx*vx+vy*vy)
    if len>250 then
      s=(len-250)/len
      vx,vy=vx*s,vy*s
      x,y=x-vx,y-vy
    end
  end
  for _,l in pairs(self.elinks) do
    d=l.dev1==self and l.dev2 or l.dev1
    vx,vy=x-d.x,y-d.y
    len=math.sqrt(vx*vx+vy*vy)
    if len>250 then
      s=(len-250)/len
      vx,vy=vx*s,vy*s
      x,y=x-vx,y-vy
    end
  end
  return x,y
end

function Device:move(x,y)
  x,y=self:calc_xy(x,y)
  self.x=x
  self.y=y
end

function Device:connect(dev)
  if self==dev then
    return nil
  end
  if self.cl=="G" and dev.cl~="R" then
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
  if vec.len(self.x,self.y,dev.x,dev.y)>252 then
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
        l.dev2:del_blink(self)
      else
        l.dev2:del_elink(self)
      end
      return v
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
    if self.cl=="D" then
      self.pl.cash=self.pl.cash-(self.pl.cash/self.pl.dcnt)
      self.pl.dcnt=self.pl.dcnt-1
      self.pl.maxcash=self.pl.dcnt*1000
    end
  end
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

function Packet:initialize(d1,d2,v,srv)
  local vx,vy=d2.x-d1.x,d2.y-d1.y
  local l=math.sqrt(vx*vx+vy*vy)
  self.dev1=d1
  self.dev2=d2
  if d1.cl=="F" then
    self.pl=d2.pl
  else
    self.pl=d1.pl
  end
  self.v=v
  d1.pc=d1.pc+1
  d2.pc=d2.pc+1
  vx,vy=vx/l,vy/l
  if srv then
    self.x=d1.x
    self.y=d1.y
  else
    self.x=d1.x+vx*d1.r
    self.y=d1.y+vy*d1.r
  end
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
r=15;
maxhealth=100;
maxlinks=2;
maxblinks=1;
price=100;
}

class "Router" : extends(Device) {
cl="R";
r=15;
maxhealth=100;
maxlinks=5;
maxblinks=5;
price=20;
}

class "Friend" : extends(Router) {
cl="F";
maxhealth=50;
maxlinks=1;
maxblinks=3;
price=60;
}

class "DataCenter" : extends(Device) {
cl="D";
r=15;
maxhealth=50;
maxlinks=0;
maxblinks=4;
price=200;
}

devcl={G=Generator,R=Router,F=Friend,D=DataCenter}
