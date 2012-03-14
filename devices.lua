-- vim:et

vec={}
function vec.len(x1,y1,x2,y2)
  local tx,ty=x2-x1,y2-y1
  return math.sqrt(tx*tx+ty*ty)
end

class "Player"

function Player:initialize(cash)
  self.cash=cash
  self.pkts=0
end

function Player:disconnect()
  for k,p in pairs(packets) do
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
end

function Device:calc_xy(x,y)
  local d,len,s
  local vx,vy
  for k,l in pairs(self.links) do
    d=l.dev1==self and l.dev2 or l.dev1
    vx,vy=x-d.x,y-d.y
    len=math.sqrt(vx*vx+vy*vy)
    if len>250 then
      s=(len-250)/len
      vx,vy=vx*s,vy*s
      x,y=x-vx,y-vy
    end
  end
  for k,l in pairs(self.blinks) do
    d=l.dev1==self and l.dev2 or l.dev1
    vx,vy=x-d.x,y-d.y
    len=math.sqrt(vx*vx+vy*vy)
    if len>250 then
      s=(len-250)/len
      vx,vy=vx*s,vy*s
      x,y=x-vx,y-vy
    end
  end
  for k,l in pairs(self.elinks) do
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

function Device:heal(v)
  self.health=self.health+v
  if self.health>self.maxhealth then
    self.health=self.maxhealth
  end
end

function Device:move(x,y)
  x,y=self:calc_xy(x,y)
  self.x=x
  self.y=y
end

function Device:connect(dev)
  if self==dev then
    return
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
  for i,v in ipairs(self.links) do
    if v.dev2==dev then
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
  for i,v in ipairs(self.links) do
    if v.dev2==dev then
      self:del_link(v.dev2)
      if self.pl==dev.pl then
        v.dev2:del_blink(self)
      else
        v.dev2:del_elink(self)
      end
      return v
    end
  end
  return nil
end

function Device:del_link(dev)
  for i,v in ipairs(self.links) do
    if v.dev2==dev then
      table.remove(self.links,i)
      return
    end
  end
end

function Device:del_blink(dev)
  for i,v in ipairs(self.blinks) do
    if v.dev1==dev then
      table.remove(self.blinks,i)
      return
    end
  end
end

function Device:del_elink(dev)
  for i,v in ipairs(self.elinks) do
    if v.dev1==dev then
      table.remove(self.elinks,i)
      return
    end
  end
end

function Device:del_links()
  local tmp={}
  for i,v in ipairs(self.links) do
    if v.dev1==self then
      tmp[#tmp+1]=v
    end
  end
  for k,v in pairs(tmp) do
    self:del_link(v.dev2)
    if self.pl==v.dev2.pl then
      v.dev2:del_blink(self)
    else
      v.dev2:del_elink(self)
    end
    links:del(v)
  end
  tmp={}
  for i,v in ipairs(self.blinks) do
    if v.dev2==self then
      tmp[#tmp+1]=v
    end
  end
  for k,v in pairs(tmp) do
    self:del_blink(v.dev1)
    v.dev1:del_link(self)
    links:del(v)
  end
  tmp={}
  for i,v in ipairs(self.elinks) do
    if v.dev2==self then
      tmp[#tmp+1]=v
    end
  end
  for k,v in pairs(tmp) do
    self:del_elink(v.dev1)
    v.dev1:del_link(self)
    links:del(v)
  end
end

function Device:delete()
  for k,p in pairs(packets) do
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
end

class "Link"

function Link:initialize(d1,d2)
  self.dev1=d1
  self.dev2=d2
end

function Link:del_packets()
  local d1=self.dev1
  local d2=self.dev2
  for k,p in pairs(packets) do
    if (p.dev1==d1 and p.dev2==d2) or (p.dev1==d2 and p.dev2==d1) then
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
  self.pl=d1.pl
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
    if d1.pl==ME then
      ME.pkts=ME.pkts-1
    end
    return true
  end
  return false
end

class "Generator" : extends(Device) {
cl="G";
r=15;
maxhealth=50;
maxlinks=2;
maxblinks=1;
price=50;
}

class "Router" : extends(Device) {
cl="R";
r=15;
maxhealth=20;
maxlinks=5;
maxblinks=5;
price=10;
}

class "DataCenter" : extends(Device) {
cl="D";
r=15;
maxhealth=40;
maxlinks=0;
maxblinks=4;
price=20;
}

devcl={G=Generator,R=Router,D=DataCenter}
