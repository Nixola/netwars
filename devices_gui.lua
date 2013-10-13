-- vim:et

local pi2=math.pi*2

class "Packet"

function Packet:initialize(d1,d2)
  local vx,vy=d2.x-d1.x,d2.y-d1.y
  local l=sqrt(vx*vx+vy*vy)
  self.dev1=d1
  self.dev2=d2
  self.pl=d2.pl
  self.tou=not d2.isdev
  vx,vy=vx/l,vy/l
  self.x1=d1.x+vx*d1.r
  self.y1=d1.y+vy*d1.r
  self.x4=d2.x-vx*d2.r
  self.y4=d2.y-vy*d2.r
  l=l/2-3
  local tx,ty
  if random()>0.5 then
    tx,ty=vy*9,-vx*9
  else
    tx,ty=-vy*9,vx*9
  end
  self.x2=d1.x+vx*l+tx
  self.y2=d1.y+vy*l+ty
  self.x3=d2.x-vx*l-tx
  self.y3=d2.y-vy*l-ty
  self.lt=255
  self.dt=0
  self.cnt=1
  d1.pc=d1.pc+1
  if not self.tou then
    d2.pc=d2.pc+1
  end
  if self.pl==ME then
    ME.pkts=ME.pkts+1
  end
end

function Packet:delete()
  local d1=self.dev1
  local d2=self.dev2
  d1.pc=d1.pc-1
  if not self.tou then
    d2.pc=d2.pc-1
  end
  if self.pl==ME then
    ME.pkts=ME.pkts-1
  end
end

function Packet:flow(dt)
  self.lt=self.lt-dt*400
  self.dt=self.dt+dt
  if self.dt>=0.05 then
    self.dt=self.dt-0.05
    self.cnt=self.cnt+1
  end
  if self.tou then
    return self.lt<84
  end
  return self.lt<56
end

function Packet:draw()
  local col={0,0,0}
  local i=2
  if self.tou then
    i=self.pl==ME and 3 or 1
  end
  graph.setLine(2,"smooth")
  if self.cnt>=3 then
    col[i]=self.lt-40
    graph.setColor(col)
    graph.line(self.x1,self.y1,self.x2,self.y2)
    col[i]=self.lt-20
    graph.setColor(col)
    graph.line(self.x2,self.y2,self.x3,self.y3)
    col[i]=self.lt
    graph.setColor(col)
    graph.line(self.x3,self.y3,self.x4,self.y4)
    return
  end
  if self.cnt==2 then
    col[i]=self.lt-20
    graph.setColor(col)
    graph.line(self.x1,self.y1,self.x2,self.y2)
    col[i]=self.lt
    graph.setColor(col)
    graph.line(self.x2,self.y2,self.x3,self.y3)
    return
  end
  col[i]=self.lt
  graph.setColor(col)
  graph.line(self.x1,self.y1,self.x2,self.y2)
end

class "Shot"

function Shot:initialize(o1,o2)
  local vx,vy=o2.x-o1.x,o2.y-o1.y
  local l=sqrt(vx*vx+vy*vy)
  self.obj1=o1
  self.obj2=o2
  self.pl=o1.pl
  vx,vy=vx/l,vy/l
  self.x1=o1.x+vx*o1.r
  self.y1=o1.y+vy*o1.r
  self.x3=o2.x
  self.y3=o2.y
  l=l/2+o1.r/2
  self.x2=o1.x+vx*l
  self.y2=o1.y+vy*l
  self.lt=0
  self.dt=0
  self.cnt=1
end

function Shot:flow(dt)
  self.lt=self.lt+dt*320
  self.dt=self.dt+dt
  if self.dt>=0.05 then
    self.dt=self.dt-0.05
    self.cnt=self.cnt+1
  end
  return self.lt>64
end

function Shot:draw()
  if self.pl==ME then
    local col={128,192,240}
    local r,g,b
    graph.setLine(2,"smooth")
    if self.cnt>1 then
      r=col[1]-self.lt-32
      g=col[2]-self.lt-32
      b=col[3]-self.lt-32
      graph.setColor(r,g,b)
      graph.line(self.x1,self.y1,self.x2,self.y2)
      r=col[1]-self.lt
      g=col[2]-self.lt
      b=col[3]-self.lt
      graph.setColor(r,g,b)
      graph.line(self.x2,self.y2,self.x3,self.y3)
      return
    end
    r=col[1]-self.lt
    g=col[2]-self.lt
    b=col[3]-self.lt
    graph.setColor(r,g,b)
    graph.line(self.x1,self.y1,self.x2,self.y2)
  else
    local col={255,96,64}
    local r,g,b
    graph.setLine(2,"smooth")
    if self.cnt>1 then
      r=col[1]-self.lt
      g=col[2]-self.lt-32
      b=col[3]-self.lt
      graph.setColor(r,g,b)
      graph.line(self.x1,self.y1,self.x2,self.y2)
      r=col[1]-self.lt
      g=col[2]-self.lt
      b=col[3]-self.lt
      graph.setColor(r,g,b)
      graph.line(self.x2,self.y2,self.x3,self.y3)
      return
    end
    r=col[1]-self.lt
    g=col[2]-self.lt
    b=col[3]-self.lt
    graph.setColor(r,g,b)
    graph.line(self.x1,self.y1,self.x2,self.y2)
  end
end

function Device:link(dev)
  self.initok=true
  local l=self:connect(dev)
  if l then
    links:add(l)
  end
end

function Device:draw_bar()
  local w=self.r*2
  local p=self.health/self.maxhealth
  local n=floor(w*p)
  local c=floor(48*p)
  local x,y=self.x-self.r,self.y-self.r-6
  local re=c>=32 and 250-((c-32)*15) or 250
  local gr=c<=24 and c*10 or 250
  if n>0 then
    if self.online then
      graph.setColor(re,gr,0)
    else
      graph.setColor(160,160,160)
    end
    graph.rectangle("fill",x,y,n,3)
  end
end

function Device:draw_sym(_x,_y)
  local x=_x or self.x
  local y=_y or self.y
  if self.hud then
    graph.setColor(0,0,255)
  elseif not self.pl then
    if self.cl=="G" then
      graph.setColor(74,170,196)
    else
      graph.setColor(96,96,96)
    end
  elseif self.pl==ME then
    graph.setColor(0,0,255)
  else
    if ally[self.pl] then
      graph.setColor(0,160,0)
    else
      graph.setColor(255,0,0)
    end
  end
  graph.circle("fill",x,y,self.r,24)
  graph.setColor(255,255,255)
  graph.setLine(1,"rough")
  graph.circle("line",x,y,self.r,24)
  if self.hud or eye.s>0.6 then
    graph.setColorMode("replace")
    graph.draw(self.img,x-8,y-8)
  end
end

function Device:draw_cborder(_x,_y,ok)
  local x=_x or self.x
  local y=_y or self.y
  if self.hud or self.pl==ME or self.cl=="G" then
    if ok==nil or ok==true then
      graph.setColor(255,255,255)
    else
      graph.setColor(255,0,0)
    end
    graph.setLine(1,"rough")
    graph.circle("line",x,y,self.cr,24)
  end
end

function Device:draw_rng(_x,_y,_drag)
  local x=_x or self.x
  local y=_y or self.y
  if _drag or self.hud then
    graph.setLine(1,"rough")
    graph.setColor(0,255,0)
    graph.circle("line",x,y,LINK,24)
    if self.cl=="R" then
      graph.setColor(0,0,255)
      graph.circle("line",x,y,SHOTR,24)
    end
    if self.cl=="T" then
      graph.setColor(255,0,0)
      graph.circle("line",x,y,SHOTT,24)
    end
    return
  end
  if self.ec then
    graph.setLine(1,"rough")
    graph.setColor(0,255,0)
    graph.circle("line",x,y,LINK,24)
  end
  if self.cl=="R" then
    graph.setLine(1,"rough")
    graph.setColor(0,0,255)
    graph.circle("line",x,y,SHOTR,24)
  end
  if self.cl=="T" then
    graph.setLine(1,"rough")
    graph.setColor(255,0,0)
    graph.circle("line",x,y,SHOTT,24)
  end
end

function Device:draw()
  self:draw_sym()
  if eye.s>0.4 then
    self:draw_bar()
  end
end

function Device:drag(x,y)
  x,y=self:calc_xy(x,y)
  local ok=self:chk_border(x,y)
  self:draw_sym(x,y)
  self:draw_cborder(x,y,ok)
  self:draw_rng(x,y,true)
end

function Device:is_pointed(x,y)
  local tx,ty=self.x-x,self.y-y
  local r=sqrt(tx*tx+ty*ty)
  return r<=self.r
end

function Device:switch(b)
  self.online=b
  self.li=1
  if b then
    self.menu:switch("Online","Offline")
  else
    self.menu:switch("Offline","Online")
  end
end

function Device:net_buy(x,y)
  if ME.cash>=self.price then
    net_send("B:%s:%d:%d",self.cl,x,y)
  end
end

function Device:net_move(x,y)
  if self.nomove then
    return
  end
  if not self.online and self.pc<1 then
    x,y=self:calc_xy(x,y)
    if self:chk_border(x,y) then
      net_send("M:%d:%d:%d",self.idx,x,y)
    end
  end
end

function Device:net_connect(dev)
  if not self.initok then
    return
  end
  if self==dev then
    return
  end
  if self.cl=="B" and dev.cl~="R" then
    return
  end
  if self.cl=="G" and dev.cl~="R" and dev.pl~=ME then
    return
  end
  if #self.links>=self.maxlinks then
    return
  end
  if #dev.blinks>=dev.maxblinks then
    return nil
  end
  local tx,ty=self.x-dev.x,self.y-dev.y
  local len=floor(sqrt(tx*tx+ty*ty))
  if len>LINK then
    return
  end
  local ok=true
  for _,l in ipairs(self.links) do
    if l.dev2==dev then
      ok=false
      break
    end
  end
  if ok then
    net_send("Lc:%d:%d",self.idx,dev.idx)
  end
end

function Device:net_unlink(dev)
  if self.cl=="G" and dev.pl~=ME then
    return
  end
  for _,l in ipairs(self.links) do
    if l.dev2==dev then
      net_send("Lu:%d:%d",self.idx,dev.idx)
      return
    end
  end
end

function Device:net_unlink_all()
  net_send("LU:%d",self.idx)
end

function Device:net_switch()
  if not self.initok then
    return
  end
  if self.online then
    net_send("S:%d:0",self.idx)
  else
    net_send("S:%d:1",self.idx)
  end
end

function Device:net_upgrade()
  if self.em then
    net_send("U:%d",self.idx)
  end
end

function Link:draw()
  graph.setColor(200,200,200)
  if love._ver >= 80 then
    stipple.setLine(1,"rough")
    stipple:draw(self.dev1.x, self.dev1.y, self.dev2.x, self.dev2.y)
  else
    graph.setLine(1,"rough")
    graph.line(self.dev1.x,self.dev1.y,self.dev2.x,self.dev2.y)
  end
end

function Unit:draw_bar()
  local w=self.r*2
  local p=self.health/self.maxhealth
  local n=floor(w*p)
  local c=floor(48*p)
  local x,y=self.x-self.r,self.y-self.r-6
  local re=c>=32 and 250-((c-32)*15) or 250
  local gr=c<=24 and c*10 or 250
  if n>0 then
    graph.setColor(re,gr,0)
    graph.rectangle("fill",x,y,n,3)
  end
  if self.maxpkt then
    p=self.pkt/self.maxpkt
    n=floor(w*p)
    x,y=self.x-self.r,self.y+self.r+3
    if n>0 then
      graph.setColor(255,255,255)
      graph.rectangle("fill",x,y,n,3)
    end
  end
end

function Unit:draw_sym(_x,_y)
  local x=_x or self.x
  local y=_y or self.y
  if self.hud then
    if self.buyonce then
      graph.setColor(0,0,160)
    else
      graph.setColor(0,0,255)
    end
  elseif not self.pl then
    graph.setColor(128,128,128)
  elseif self.pl==ME then
    graph.setColor(0,0,255)
  else
    if ally[self.pl] then
      graph.setColor(0,160,0)
    else
      graph.setColor(255,0,0)
    end
  end
  graph.circle("fill",x,y,self.r,12)
  graph.setColor(255,255,255)
  graph.setLine(1,"rough")
  graph.circle("line",x,y,self.r,12)
  if self.hud or eye.s>0.9 then
    graph.setColorMode("replace")
    graph.draw(self.img,x-4,y-4)
  end
end

function Unit:draw_rng(_x,_y)
  local x=_x or self.x
  local y=_y or self.y
  graph.setLine(1,"rough")
  if self.cl=="t" then
    if self.hud then
      graph.setColor(0,0,255)
    else
      graph.setColor(255,0,0)
    end
    graph.circle("line",x,y,SHOTR,24)
  end
end

function Unit:draw()
  self:draw_sym()
  if eye.s>0.4 then
    self:draw_bar()
  end
  if self.pl==ME and self.vx and self.vy then
    graph.setColor(192,192,192)
    graph.setLine(1,"rough")
    graph.line(self.x,self.y,self.mx,self.my)
  end
end

function Unit:_step(dt)
  if not (self.vx and self.vy) then
    return false
  end
  local x=self.tx+self.vx*dt
  local y=self.ty+self.vy*dt
  local tx,ty=x-self.ix,y-self.iy
  local len=sqrt(tx*tx+ty*ty)
  if len>=self.dist then
    self.x=self.mx
    self.y=self.my
    self.vx=nil
    self.vy=nil
    return true
  end
  self.tx=x
  self.ty=y
  self.x=floor(x)
  self.y=floor(y)
  return false
end

function Unit:drag(x,y)
  self:draw_sym(x,y)
  self:draw_rng(x,y)
end

function Unit:is_pointed(x,y)
  local tx,ty=self.x-x,self.y-y
  local r=sqrt(tx*tx+ty*ty)
  return r<=self.r
end

function Unit:net_buy(x,y)
  if ME.cash>=self.price then
    net_send("B:%s:%d:%d",self.cl,x,y)
  end
end

function Unit:net_move(x,y)
  x,y=self:calc_xy(x,y)
  net_send("Um:%d:%d:%d",self.idx,x,y)
end

function Power:draw_st()
  local w=self.r*2
  local p=self.pwr/10
  local n=floor(w*p)
  local x,y=self.x-self.r,self.y+self.r+3
  if n>0 then
    graph.setColor(255,128,255)
    graph.rectangle("fill",x,y,n,3)
  end
end

function Power:draw()
  self:super("draw")
  if eye.s>0.4 then
    self:draw_st()
  end
end

function Router:draw_st()
  local w=self.r*2
  local p=self.pkt/self.maxpkt
  local n=floor(w*p)
  local x,y=self.x-self.r,self.y+self.r+3
  if n>0 then
    graph.setColor(255,255,255)
    graph.rectangle("fill",x,y,n,3)
  end
  p=self.ec/self.em
  n=floor(w*p)
  x,y=self.x-self.r-6,self.y+self.r-n
  if n>0 then
    graph.setColor(128,192,240)
    graph.rectangle("fill",x,y,3,n)
  end
end

function Router:draw()
  self:super("draw")
  if eye.s>0.4 then
    self:draw_st()
  end
end

function Tower:draw_st()
  local w=self.r*2
  local p=self.pkt/self.maxpkt
  local n=floor(w*p)
  local x,y=self.x-self.r,self.y+self.r+3
  if n>0 then
    graph.setColor(255,255,255)
    graph.rectangle("fill",x,y,n,3)
  end
end

function Tower:draw()
  self:super("draw")
  if eye.s>0.4 then
    self:draw_st()
  end
end

function Power:init_gui()
  self.menu=Menu:new(self)
  self.menu:add("Online",Device.net_switch)
  return
end

function Router:init_gui()
  self.menu=Menu:new(self)
  self.menu:add("Upgrade",Device.net_upgrade)
  self.menu:add("Online",Device.net_switch)
  self.menu:add("Unlink",Device.net_unlink_all)
end

function Vault:init_gui()
  self.menu=Menu:new(self)
  self.menu:add("Online",Device.net_switch)
  self.menu:add("Unlink",Device.net_unlink_all)
end

function Tower:init_gui()
  self.menu=Menu:new(self)
  self.menu:add("Online",Device.net_switch)
  self.menu:add("Unlink",Device.net_unlink_all)
end
