-- vim:et

local pi2=math.pi*2

class "Packet"

function Packet:initialize(d1,d2)
  local vx,vy=d2.x-d1.x,d2.y-d1.y
  local l=math.sqrt(vx*vx+vy*vy)
  self.dev1=d1
  self.dev2=d2
  self.pl=d1.cl=="F" and d2.pl or d1.pl
  vx,vy=vx/l,vy/l
  self.x1=d1.x+vx*d1.r
  self.y1=d1.y+vy*d1.r
  self.x4=d2.x-vx*d2.r
  self.y4=d2.y-vy*d2.r
  l=l/2-3
  local tx,ty
  if math.random()>0.5 then
    tx,ty=vy*9,-vx*9
  else
    tx,ty=-vy*9,vx*9
  end
  self.x2=d1.x+vx*l+tx
  self.y2=d1.y+vy*l+ty
  self.x3=d2.x-vx*l-tx
  self.y3=d2.y-vy*l-ty
  self.ttl=255
  self.dt=0
  self.cnt=1
  d1.pc=d1.pc+1
  d2.pc=d2.pc+1
  if self.pl==ME then
    ME.pkts=ME.pkts+1
  end
end

function Packet:delete()
  local d1=self.dev1
  local d2=self.dev2
  d1.pc=d1.pc-1
  d2.pc=d2.pc-1
  if self.pl==ME then
    ME.pkts=ME.pkts-1
  end
end

function Packet:flow(dt)
  self.ttl=self.ttl-dt*400
  self.dt=self.dt+dt
  if self.dt>=0.05 then
    self.dt=self.dt-0.05
    self.cnt=self.cnt+1
  end
  return self.ttl<56
end

function Packet:draw()
  if eye.in_view(self.dev1.x,self.dev1.y,self.dev1.r) or eye.in_view(self.dev2.x,self.dev2.y,self.dev2.r) then
    local col={0,0,0}
    local i=self.pl==ME and 2 or 1
    graph.setLine(2,"smooth")
    if self.cnt>=3 then
      col[i]=self.ttl-40
      graph.setColor(col)
      graph.line(self.x1,self.y1,self.x2,self.y2)
      col[i]=self.ttl-20
      graph.setColor(col)
      graph.line(self.x2,self.y2,self.x3,self.y3)
      col[i]=self.ttl
      graph.setColor(col)
      graph.line(self.x3,self.y3,self.x4,self.y4)
      return
    end
    if self.cnt==2 then
      col[i]=self.ttl-20
      graph.setColor(col)
      graph.line(self.x1,self.y1,self.x2,self.y2)
      col[i]=self.ttl
      graph.setColor(col)
      graph.line(self.x2,self.y2,self.x3,self.y3)
      return
    end
    col[i]=self.ttl
    graph.setColor(col)
    graph.line(self.x1,self.y1,self.x2,self.y2)
  end
end

function Device:draw_bar()
  local p=self.health/self.maxhealth
  local x,y,w=self.x-self.r,self.y-self.r-6,self.r*2
  local n=math.floor(w*p)
  local c=math.floor(48*p)
  local re=c>=32 and 250-((c-32)*15) or 250
  local gr=c<=24 and c*10 or 250
  if n>0 then
    graph.setColor(re,gr,0)
    graph.rectangle("fill",x,y,n,3)
  end
end

function Device:draw_sym(_x,_y)
  local x=_x or self.x
  local y=_y or self.y
  if self.hud then
    if self.buyonce then
      graph.setColor(0,0,160)
    else
      graph.setColor(0,0,255)
    end
  elseif (not self.pl) then
    graph.setColor(128,128,128)
  elseif self.pl==ME then
    if self.online then
      graph.setColor(0,0,255)
    else
      graph.setColor(0,0,160)
    end
  else
    if self.online then
      graph.setColor(255,0,0)
    else
      graph.setColor(160,0,0)
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

function Device:draw_border()
  if (not self.pl) then
    graph.setColor(64,64,64)
  elseif self.pl==ME then
    graph.setColor(0,0,96)
  else
    graph.setColor(96,0,0)
  end
  graph.circle("fill",self.x,self.y,self.er,24)
end

function Device:draw_cborder(_x,_y,c)
  local x=_x or self.x
  local y=_y or self.y
  if self.hud or self.pl==ME then
    if c==1 then
      graph.setColor(255,0,0)
    else
      graph.setColor(255,255,255)
    end
    graph.setLine(1,"rough")
    graph.circle("line",x,y,self.cr,24)
  end
end

function Device:draw_eborder(_x,_y,c)
  local x=_x or self.x
  local y=_y or self.y
  if self.hud or self.pl==ME then
    if c==2 then
      graph.setColor(255,0,0)
    else
      graph.setColor(255,255,255)
    end
    graph.setLine(1,"rough")
    graph.circle("line",x,y,self.er,24)
  end
end

function Device:draw()
  if eye.in_view(self.x,self.y,self.er) then
    self:draw_sym()
    if eye.s>0.4 then
      self:draw_bar()
    end
    return true
  end
  return false
end

function Device:chk_border2(x,y)
  local t=devhash:get(self:bound_box(x,y))
  local ok=true
  local len,vx,vy
  local br,tp,pl
  for _,d in pairs(t) do
    if self~=d then
      vx,vy=x-d.x,y-d.y
      len=math.floor(math.sqrt(vx*vx+vy*vy))
      pl=self.hud and ME or self.pl
      br=pl==d.pl and d.cr or d.er
      if len<=br*2 then
        ok=false
        tp=pl==d.pl and 1 or 2
        break
      end
    end
  end
  return ok,tp
end

function Device:drag(x,y)
  x,y=self:calc_xy(x,y)
  local ok,tp=self:chk_border2(x,y)
  self:draw_sym(x,y)
  self:draw_cborder(x,y,tp)
  self:draw_eborder(x,y,tp)
end

function Device:is_pointed(x,y)
  local tx,ty=self.x-x,self.y-y
  local r=math.sqrt(tx*tx+ty*ty)
  return r<=self.r
end

function Device:is_epointed(x,y)
  local tx,ty=self.x-x,self.y-y
  local r=math.sqrt(tx*tx+ty*ty)
  return r<=self.er
end

function Device:switch(b)
  self.online=b
  self.li=1
  self.dt=0
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

function Device:net_delete()
  net_send("D:%d",self.idx)
end

function Device:net_move(x,y)
  if self.nomove then
    return
  end
  if (not self.online) and self.pc<1 and #self.elinks<1 then
    x,y=self:calc_xy(x,y)
    if self:chk_border(x,y) then
      net_send("M:%d:%d:%d",self.idx,x,y)
    end
  end
end

function Device:net_connect(dev)
  if self==dev then
    return
  end
  if self.cl=="G" and (self.pl~=dev.pl or dev.cl~="R") then
    return
  end
  if self.cl=="B" and (self.pl~=dev.pl or dev.cl~="R") then
    return
  end
  if #self.links>=self.maxlinks then
    return
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
  local tx,ty=self.x-dev.x,self.y-dev.y
  local len=math.floor(math.sqrt(tx*tx+ty*ty))
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
    net_send("L:%d:%d",self.idx,dev.idx)
  end
end

function Device:net_unlink(dev)
  for _,l in ipairs(self.links) do
    if l.dev2==dev then
      net_send("U:%d:%d",self.idx,dev.idx)
      return
    end
  end
end

function Device:net_switch()
  if self.online then
    net_send("S:%d:0",self.idx)
  else
    net_send("S:%d:1",self.idx)
  end
end

function Link:draw()
  if eye.in_view(self.dev1.x,self.dev1.y,self.dev1.r) or eye.in_view(self.dev2.x,self.dev2.y,self.dev2.r) then
    graph.setColor(200,200,200)
    graph.setLine(1,"rough")
    graph.line(self.dev1.x,self.dev1.y,self.dev2.x,self.dev2.y)
  end
end

function Generator:draw_st()
  local p=self.pwr/MAXV
  local x,y,w=self.x-self.r,self.y+self.r+3,self.r*2
  local n=math.floor(w*p)
  if n>0 then
    graph.setColor(255,128,255)
    graph.rectangle("fill",x,y,n,3)
  end
end

function Generator:draw()
  if self:super("draw") then
    if eye.s>0.4 then
      self:draw_st()
    end
  end
end

function Router:draw_st()
  local p=self.pkt/MAXP
  local x,y,w=self.x-self.r,self.y+self.r+3,self.r*2
  local n=math.floor(w*p)
  if n>0 then
    graph.setColor(255,255,255)
    graph.rectangle("fill",x,y,n,3)
  end
end

function Router:draw()
  if self:super("draw") then
    if eye.s>0.4 then
      self:draw_st()
    end
  end
end

function DataBase:draw_st()
  local p=self.pwr/MAXV
  local x,y,w=self.x-self.r,self.y+self.r+3,self.r*2
  local n=math.floor(w*p)
  if n>0 then
    graph.setColor(255,128,255)
    graph.rectangle("fill",x,y,n,3)
  end
end

function DataBase:draw()
  if self:super("draw") then
    if eye.s>0.4 then
      self:draw_st()
    end
  end
end

function Generator:init_gui()
  self.menu=Menu:new(self)
  self.menu:add("Online",Device.net_switch)
end

function Router:init_gui()
  self.menu=Menu:new(self)
  self.menu:add("Online",Device.net_switch)
  self.menu:add("Delete",Device.net_delete)
end

function Friend:init_gui()
  self.menu=Menu:new(self)
  self.menu:add("Online",Device.net_switch)
  self.menu:add("Delete",Device.net_delete)
end

function DataCenter:init_gui()
  self.menu=Menu:new(self)
  self.menu:add("Online",Device.net_switch)
  self.menu:add("Delete",Device.net_delete)
end

function DataBase:init_gui()
  self.menu=Menu:new(self)
  self.menu:add("Online",Device.net_switch)
  self.menu:add("Delete",Device.net_delete)
end
