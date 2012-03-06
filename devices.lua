class "Device"

function Device:initialize(x,y)
  self.x=x
  self.y=y
  self.health=self.maxhealth
  self.links=list()
end

function Device:draw_bar(p)
  local poly={}
  local pi2=math.pi*2
  local off=time%pi2
  local m=48
  --local p=self.health/self.maxhealth
  local n=math.floor(m*p)
  local x,y,s
  local re=n>=32 and 250-((n-32)*15) or 250
  local gr=n<=24 and n*10 or 250
  graph.setColor(re,gr,0)
  for t=0,n-1 do
    s=t
    x=math.sin((s/m)*pi2+off)
    y=math.cos((s/m)*pi2+off)
    poly[1]=self.x+((self.r+6)*x)
    poly[2]=self.y+((self.r+6)*y)
    poly[3]=self.x+((self.r+3)*x)
    poly[4]=self.y+((self.r+3)*y)
    s=s+1.0
    x=math.sin((s/m)*pi2+off)
    y=math.cos((s/m)*pi2+off)
    poly[5]=self.x+((self.r+3)*x)
    poly[6]=self.y+((self.r+3)*y)
    poly[7]=self.x+((self.r+6)*x)
    poly[8]=self.y+((self.r+6)*y)
    graph.polygon("fill",poly)
  end
end

function Device:draw()
  self:draw_bar(((time/5)%1.00))
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

class "Link"

function Link:initialize(d1,d2)
  self.d1=d1
  self.d2=d2
end

function Link:draw()
  if eye.in_view(self.d1.x,self.d1.y,self.d1.r) or eye.in_view(self.d2.x,self.d2.y,self.d2.r) then
    graph.setColor(200,200,200)
    graph.line(self.d1.x,self.d1.y,self.d2.x,self.d2.y)
  end
end

class "Packet"

function Packet:initialize()
end

class "Generator" : extends(Device) {
r=10;
maxhealth=20;
maxlinks=1;
}

function Generator:draw()
  if eye.in_view(self.x,self.y,self.r) then
    graph.setColor(0,0,255)
    graph.circle("fill",self.x,self.y,self.r,24)
    self:super("draw")
  end
end
