-- vim:et

class "Device"

function Device:initialize(x,y)
  self.x=x
  self.y=y
  self.online=false
  self.off=0
  self.health=self.maxhealth
  self.links=list()
end

function Device:draw_bar(p)
  local poly={}
  local pi2=math.pi*2
  local m=48
  --local p=self.health/self.maxhealth
  local n=math.floor(m*p)
  local x,y,s
  local re=n>=32 and 250-((n-32)*15) or 250
  local gr=n<=24 and n*10 or 250
  if self.online then
    self.off=(self.off+dtime)%pi2
  end
  graph.setColor(re,gr,0)
  for t=0,n-1 do
    s=t
    x=math.sin((s/m)*pi2+self.off)
    y=math.cos((s/m)*pi2+self.off)
    poly[1]=self.x+((self.r+6)*x)
    poly[2]=self.y+((self.r+6)*y)
    poly[3]=self.x+((self.r+3)*x)
    poly[4]=self.y+((self.r+3)*y)
    s=s+1.0
    x=math.sin((s/m)*pi2+self.off)
    y=math.cos((s/m)*pi2+self.off)
    poly[5]=self.x+((self.r+3)*x)
    poly[6]=self.y+((self.r+3)*y)
    poly[7]=self.x+((self.r+6)*x)
    poly[8]=self.y+((self.r+6)*y)
    graph.polygon("fill",poly)
  end
end

function Device:draw()
  self:draw_bar(0.3)
  --self:draw_bar(1.00)
end

function Device:move(x,y)
  local len,s
  local vx,vy
  for l in self.links:iter() do
    d=l.d1==self and l.d2 or l.d1
    vx,vy=x-d.x,y-d.y
    len=math.sqrt(vx*vx+vy*vy)
    if len>200 then
      s=(len-200)/len
      vx,vy=vx*s,vy*s
      x,y=x-vx,y-vy
    end
  end
  self.x=x
  self.y=y
end

function Device:is_pointed(x,y)
  local tx,ty=self.x-x,self.y-y
  local r=math.sqrt(tx*tx+ty*ty)
  return r<=self.r and math.abs(tx)<=r and math.abs(ty)<=r and true or false
end

function Device:connect(d)
  if self.links:count()>=self.maxlinks then
    return
  end
  if d.links:count()>=d.maxlinks then
    return
  end
  if vec.len(self.x,self.y,d.x,d.y)>200 then
    return
  end
  l=Link:new(self,d)
  links:add(l)
  self.links:add(l)
  d.links:add(l)
end

function Device:switch()
  if self.online then
    self.online=false
    self.menu.items[2].str="Online"
  else
    self.online=true
    self.menu.items[2].str="Offline"
  end
end

class "Link"

function Link:initialize(d1,d2)
  self.d1=d1
  self.d2=d2
end

function Link:draw()
  if eye.in_view(self.d1.x,self.d1.y,self.d1.r) or eye.in_view(self.d2.x,self.d2.y,self.d2.r) then
    graph.setColor(200,200,200)
    graph.setLine(1,"rough")
    graph.line(self.d1.x,self.d1.y,self.d2.x,self.d2.y)
  end
end

class "Packet" {
r=3;
}

function Packet:initialize(d1,d2)
  local vx,vy=d2.x-d1.x,d2.y-d1.y
  local s=math.sqrt(vx*vx+vy*vy)
  self.d1=d1
  self.d2=d2
  vx,vy=vx/s,vy/s
  self.x=d1.x+vx*d1.r
  self.y=d1.y+vy*d1.r
end

function Packet:draw()
  if eye.in_view(self.x,self.y,self.r) then
    graph.setColor(0,255,0)
    graph.setLine(1,"rough")
    graph.circle("line",self.x,self.y,self.r,8)
  end
end

function Packet:step(dt)
  local vx,vy=self.d2.x-self.d1.x,self.d2.y-self.d1.y
  local s=math.sqrt(vx*vx+vy*vy)
  vx,vy=vx/s*2,vy/s*2
  self.x=self.x+vx
  self.y=self.y+vy
  local tx,ty=self.d2.x-self.x,self.d2.y-self.y
  local r=math.sqrt(tx*tx+ty*ty)
  if r<=self.d2.r then
    packets:wipe(self)
  end
end

class "Generator" : extends(Device) {
r=15;
maxhealth=20;
maxlinks=4;
}

function Generator:initialize(x,y)
  self:super("initialize",x,y)
  self.menu=Menu:new(self)
  self.menu:add("Connect",mn_dev_conn)
  self.menu:add("Online",Device.switch)
  self.menu:add("Delete",mn_dev_del)
end

function Generator:draw()
  if eye.in_view(self.x,self.y,self.r) then
    graph.setColor(0,0,255)
    graph.circle("fill",self.x,self.y,self.r,24)
    if eye.s>0.3 then
      graph.setColor(255,255,255)
      graph.setLineWidth(2,"smooth")
      graph.rectangle("line",self.x-8,self.y-8,17,17)
    end
    self:super("draw")
  end
end

function Generator:emit()
  local l=self.links:head()
  if l then
    local d2=l.d1==self and l.d2 or l.d1
    packets:add(Packet:new(self,d2))
  end
end
