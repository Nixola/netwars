class "Device"

function Device:initialize(x,y)
  self.x=x
  self.y=y
  self.health=self.maxhealth
  self.conns=List:new()
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

function Device:draw_conns()
end

function Device:draw()
  self:draw_bar(((time/5)%1.00))
  --self:draw_bar(1.00)
end

function Device:is_pointed(x,y)
  local tx,ty=self.x-x,self.y-y
  local r=math.sqrt(tx*tx+ty*ty)
  return r<=self.r and math.abs(tx)<=r and math.abs(ty)<=r and true or false
end

class "Generator" : extends(Device) {
r=10;
maxhealth=20;
}

function Generator:draw()
  graph.setColor(0,0,255)
  graph.circle("fill",self.x,self.y,self.r,24)
  self:super("draw")
end
