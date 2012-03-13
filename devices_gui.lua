-- vim:et

function Device:draw_bar()
  local poly={}
  local pi2=math.pi*2
  local m=48
  local p=self.health/self.maxhealth
  local n=math.floor(m*p)
  local x,y,s
  local re=n>=32 and 250-((n-32)*15) or 250
  local gr=n<=24 and n*10 or 250
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

function Device:draw_st()
  local poly={}
  local pi2=math.pi*2
  local m=48
  if self.online then
    local off=self.off*3
    for t=0,4 do
      s=t
      graph.setColor(255,255,255)
      x=math.sin((s/m)*pi2-off)
      y=math.cos((s/m)*pi2-off)
      poly[1]=self.x+((self.r+3)*x)
      poly[2]=self.y+((self.r+3)*y)
      poly[3]=self.x+((self.r)*x)
      poly[4]=self.y+((self.r)*y)
      s=s+1.0
      x=math.sin((s/m)*pi2-off)
      y=math.cos((s/m)*pi2-off)
      poly[5]=self.x+((self.r)*x)
      poly[6]=self.y+((self.r)*y)
      poly[7]=self.x+((self.r+3)*x)
      poly[8]=self.y+((self.r+3)*y)
      graph.polygon("fill",poly)
    end
  end
end

function Device:draw_sym(_x,_y)
  local x=_x or self.x
  local y=_y or self.y
  if (not self.pl) or self.pl==ME then
    graph.setColor(0,0,255)
  else
    graph.setColor(255,0,0)
  end
  graph.circle("fill",x,y,self.r,24)
  if self.hud or eye.s>0.6 then
    graph.setColorMode("replace")
    graph.draw(self.img,x-8,y-8)
  end
end

function Device:draw()
  if self.online then
    local pi2=math.pi*2
    self.off=(self.off+dtime)%pi2
  end
  if eye.in_view(self.x,self.y,self.r) then
    self:draw_sym()
    if eye.s>0.6 then
      self:draw_bar()
    end
    if eye.s>0.4 then
      self:draw_st()
    end
  end
end

function Device:drag(x,y)
  x,y=self:calc_xy(x,y)
  self:draw_sym(x,y)
end

function Device:is_pointed(x,y)
  local tx,ty=self.x-x,self.y-y
  local r=math.sqrt(tx*tx+ty*ty)
  return r<=self.r and math.abs(tx)<=r and math.abs(ty)<=r and true or false
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
  if self.pc<=0 then
    x,y=self:calc_xy(x,y)
    net_send("M:%d:%d:%d",self.idx,x,y)
  end
end

function Device:net_connect(dev)
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
  if vec.len(self.x,self.y,dev.x,dev.y)>250 then
    return
  end
  local ok=true
  for i,v in ipairs(self.links) do
    if v.dev2==dev then
      ok=false
      break
    end
  end
  if ok then
    net_send("L:%d:%d",self.idx,dev.idx)
  end
end

function Device:net_unlink(dev)
  for i,v in ipairs(self.links) do
    if v.dev2==dev then
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

function Packet:draw()
  if (not self.hit) and eye.in_view(self.x,self.y,self.r) then
    if self.pl==ME then
      graph.setColor(0,255,0)
    else
      graph.setColor(255,0,0)
    end
    graph.setLine(1,"rough")
    graph.circle("line",self.x,self.y,self.r,8)
  end
end

function Generator:init_gui()
  self.menu=Menu:new(self)
  self.menu:add("Connect",mn_dev_conn)
  self.menu:add("Unlink",mn_dev_unlink)
  self.menu:add("Online",Device.net_switch)
  self.menu:add("Delete",Device.net_delete)
end

function Router:init_gui()
  self.menu=Menu:new(self)
  self.menu:add("Connect",mn_dev_conn)
  self.menu:add("Unlink",mn_dev_unlink)
  self.menu:add("Online",Device.net_switch)
  self.menu:add("Delete",Device.net_delete)
end

function DataCenter:init_gui()
  self.menu=Menu:new(self)
  self.menu:add("Online",Device.net_switch)
  self.menu:add("Delete",Device.net_delete)
end
