-- vim:et

function Player:del_packets()
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
  if self.pl==ME then
    mydevs[self.idx]=nil
  end
end

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
    net_send("B:%s:%d:%d\n",self.cl,x,y)
  end
end

function Device:net_delete()
  net_send("D:%d\n",self.idx)
end

function Device:net_move(x,y)
  if self.pc<=0 then
    x,y=self:calc_xy(x,y)
    net_send("M:%d:%d:%d\n",self.idx,x,y)
  end
end

function Device:net_connect(dev)
  if self.cl=="G" and dev.cl~="R" then
    return
  end
  if #self.links>=self.maxlinks then
    return
  end
  if #dev.blinks>=dev.maxblinks then
    return nil
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
    net_send("L:%d:%d\n",self.idx,dev.idx)
  end
end

function Device:net_unlink(dev)
  for i,v in ipairs(self.links) do
    if v.dev2==dev then
      net_send("U:%d:%d\n",self.idx,dev.idx)
      return
    end
  end
end

function Device:net_switch()
  if self.online then
    net_send("S:%d:0\n",self.idx)
  else
    net_send("S:%d:1\n",self.idx)
  end
end

function Link:draw()
  if eye.in_view(self.dev1.x,self.dev1.y,self.dev1.r) or eye.in_view(self.dev2.x,self.dev2.y,self.dev2.r) then
    graph.setColor(200,200,200)
    graph.setLine(1,"rough")
    graph.line(self.dev1.x,self.dev1.y,self.dev2.x,self.dev2.y)
  end
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

function Packet:flow(dt)
  local d1=self.dev1
  local d2=self.dev2
  local vx,vy=d2.x-d1.x,d2.y-d1.y
  local s=math.sqrt(vx*vx+vy*vy)
  vx,vy=vx/s*2,vy/s*2
  self.x=self.x+vx
  self.y=self.y+vy
  local tx,ty=d2.x-self.x,d2.y-self.y
  local r=math.sqrt(tx*tx+ty*ty)
  if r<=d2.r then
    d1.pc=d1.pc-1
    d2.pc=d2.pc-1
    if d1.pl==ME then
      net_send("Pf:%d:%d\n",d2.idx,self.v)
      ME.pkts=ME.pkts-1
    end
    packets:del(self)
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

function Mirror:init_gui()
  self.menu=Menu:new(self)
  self.menu:add("Online",Device.net_switch)
  self.menu:add("Delete",Device.net_delete)
end
