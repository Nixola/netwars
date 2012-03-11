-- vim:et

vec={}
function vec.len(x1,y1,x2,y2)
  local tx,ty=x2-x1,y2-y1
  return math.sqrt(tx*tx+ty*ty)
end

class "Player"

function Player:initialize(cash)
  self.cash=cash
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
  self.links[#self.links+1]=l
  dev.blinks[#dev.blinks+1]=l
  return l
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
r=15;
maxhealth=20;
maxlinks=2;
price=50;
}

function Generator:initialize(p,x,y)
  self:super("initialize",p,x,y)
  self.cl="G"
end

devcl={G=Generator}
