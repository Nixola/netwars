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
  for k,o in pairs(packets) do
    if o.dev1.pl==self or o.dev2.pl==self then
      packets[k]=nil
    end
  end
  for k,o in pairs(links) do
    if o.dev1.pl==self or o.dev2.pl==self then
      links[k]=nil
    end
  end
  for k,o in pairs(devices) do
    if o.pl==self then
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
  self.pc=0
  self.off=0
  self.health=self.maxhealth
  self.links={}
  self.blinks={}
end

function Device:delete()
  for k,o in pairs(packets) do
    if o.dev1==self or o.dev2==self then
      packets[k]=nil
    end
  end
  self:del_links()
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
  if #self.links>=self.maxlinks then
    return
  end
  if vec.len(self.x,self.y,dev.x,dev.y)>250 then
    return
  end
  local l=Link:new(self,dev)
  table.insert(self.links,l)
  table.insert(dev.blinks,l)
  return l
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

function Device:del_links()
  local l=nil
  for i,v in ipairs(self.links) do
    if v.dev1==self then
      l=v
      break
    end
  end
  if l then
    self:del_link(l.dev2)
    l.dev2:del_blink(self)
    links:del(l)
  end
  for i,v in ipairs(self.blinks) do
    if v.dev2==self then
      l=v
      break
    end
  end
  if l then
    self:del_blink(l.dev1)
    l.dev1:del_link(self)
    links:del(l)
  end
end

class "Link"

function Link:initialize(d1,d2)
  self.dev1=d1
  self.dev2=d2
end

class "Packet" {
r=3;
}

function Packet:initialize(d1,d2,v)
  local vx,vy=d2.x-d1.x,d2.y-d1.y
  local s=math.sqrt(vx*vx+vy*vy)
  self.dev1=d1
  self.dev2=d2
  self.pl=d1.pl
  self.v=v
  self.hit=false
  d1.pc=d1.pc+1
  d2.pc=d2.pc+1
  vx,vy=vx/s,vy/s
  self.x=d1.x+vx*d1.r
  self.y=d1.y+vy*d1.r
end

function Packet:route(d1,d2)
  local vx,vy=d2.x-d1.x,d2.y-d1.y
  local s=math.sqrt(vx*vx+vy*vy)
  self.dev1=d1
  self.dev2=d2
  self.hit=false
  d1.pc=d1.pc+1
  d2.pc=d2.pc+1
  vx,vy=vx/s,vy/s
  self.x=d1.x+vx*d1.r
  self.y=d1.y+vy*d1.r
end

function Packet:dequeue()
  self.dev1.pc=self.dev1.pc-1
  self.dev2.pc=self.dev2.pc-1
end

class "Generator" : extends(Device) {
cl="G";
r=15;
maxhealth=50;
maxlinks=3;
price=50;
}

class "Router" : extends(Device) {
cl="R";
r=15;
maxhealth=10;
maxlinks=5;
price=10;
}

class "DataCenter" : extends(Device) {
cl="D";
r=15;
maxhealth=20;
maxlinks=0;
price=20;
}

class "Mirror" : extends(Device) {
cl="M";
r=15;
maxhealth=10;
maxlinks=0;
price=10;
}

devcl={G=Generator,R=Router,D=DataCenter,M=Mirror}
