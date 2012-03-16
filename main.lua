-- vim:et

require "class"
require "menu"
require "devices"
require "devices_gui"
require "client"
require "init"

graph=love.graphics
dtime=0
msx,msy=0,0
mox,moy=0,0

eye={vx=0,vy=0,si=4,s=1.0}
scroll={
dt=0,run=false;
x=0,y=0,s=3,ks=0,dx=0,dy=0,kx=0,ky=0;
}

function eye.in_view(x,y,...)
  local sx=eye.cx/eye.s
  local sy=eye.cy/eye.s
  if arg.n==0 then
    local tx=math.abs(eye.vx+x)
    local ty=math.abs(eye.vy+y)
    return tx<sx and ty<sy
  end
  if arg.n==1 then
    local tx=math.abs(eye.vx+x)-arg[1]
    local ty=math.abs(eye.vy+y)-arg[1]
    return tx<sx and ty<sy
  end
  if arg.n==2 then
    local tx1=math.abs(eye.vx+x)
    local ty1=math.abs(eye.vy+y)
    local tx2=math.abs(eye.vx+arg[1])
    local ty2=math.abs(eye.vy+arg[2])
    return tx1<sx and ty1<sy or tx2<sx and ty2<sy
  end
end

function eye.scroll()
  if not scroll.run then
    return
  end
  if scroll.kx==0 then
    scroll.x=scroll.x-(scroll.x*0.2)
    if math.abs(scroll.x)<1 then
      scroll.x=0
    end
  else
    if math.abs(scroll.x)<10/eye.s then
      scroll.x=scroll.x+(scroll.kx/eye.s)
    end
  end
  if scroll.ky==0 then
    scroll.y=scroll.y-(scroll.y*0.2)
    if math.abs(scroll.y)<1 then
      scroll.y=0
    end
  else
    if math.abs(scroll.y)<10/eye.s then
      scroll.y=scroll.y+(scroll.ky/eye.s)
    end
  end
  if scroll.ks<0 then
    eye.s=eye.s+(scroll.ks/10)
    if eye.s<=scroll.s then
      eye.s=scroll.s
      scroll.ks=0
    end
  end
  if scroll.ks>0 then
    eye.s=eye.s+(scroll.ks/10)
    if eye.s>=scroll.s then
      eye.s=scroll.s
      scroll.ks=0
    end
  end
  eye.vx=eye.vx+scroll.x
  eye.vy=eye.vy+scroll.y
  eye.x=eye.vx+eye.cx/eye.s
  eye.y=eye.vy+eye.cy/eye.s
  scroll.run=scroll.x~=0 or scroll.y~=0 or scroll.ks~=0
end

ME=nil
players=ctable()
devices=ctable()
mydevs={}
links=ctable()
packets=ctable()

local buydevs=ctable()
local huddevs={}

local drag=nil
local bdrag=nil
local bdev=nil
local hover=nil
local hint=nil
local hover_dt=0
local conn=nil
local menu=nil
local kshift=false

local function get_device(x,y)
  for k,o in pairs(devices) do
    if o:is_pointed(x,y) then
      return o
    end
  end
  return nil
end

local function get_my_device(x,y)
  for k,o in pairs(devices) do
    if o:is_pointed(x,y) then
      return o.pl==ME and o or nil
    end
  end
  return nil
end

local function get_buydev(x,y)
  for k,o in pairs(buydevs) do
    if o:is_pointed(x,y) then
      return o
    end
  end
  return nil
end

local function get_enemydev(x,y)
  for k,o in pairs(devices) do
    if o:is_pointed(x,y) then
      return o.pl~=ME and o or nil
    end
  end
  return nil
end

function main_mousepressed(mx,my,b)
  local s={0.3,0.5,0.7,1.0,1.5,2.5}
  local x,y=mx/eye.s-eye.x,my/eye.s-eye.y
  if b=="wu" then
    if eye.si<#s then
      scroll.ks=math.abs(eye.s-s[eye.si+1])
      eye.si=eye.si+1
    end
    scroll.s=s[eye.si]
    scroll.run=scroll.ks~=0
    return
  end
  if b=="wd" then
    if eye.si>1 then
      scroll.ks=-math.abs(eye.s-s[eye.si-1])
      eye.si=eye.si-1
    end
    scroll.s=s[eye.si]
    scroll.run=scroll.ks~=0
    return
  end
  if menu then
    if b=="l" then
      menu=menu:click(mx,my)
      return
    end
    if b=="r" then
      menu:cleanup()
      menu=nil
    end
    return
  end
  if bdev then
    if b=="l" and my<eye.sy-50 then
      bdev:net_buy(x,y)
    end
    if b=="r" then
      bdev=nil
    end
    return
  end
  if msy>=eye.sy-50 and b=="l" then
    bdrag=get_buydev(mx,my)
    return
  end
  if b=="l" then
    local dev=get_my_device(x,y)
    if dev then
      if kshift then
        dev:net_switch()
        return
      end
      if (not dev.online) and dev.pc<1 and #dev.elinks<1 then
        drag=dev
      end
    end
    return
  end
  if b=="r" then
    conn=get_my_device(x,y)
    return
  end
end

function main_mousereleased(mx,my,b)
  local x,y=mx/eye.s-eye.x,my/eye.s-eye.y
  if drag then
    if b=="l" then
      drag:net_move(mox,moy)
      drag=nil
    end
    return
  end
  if bdrag then
    if b=="l" then
      if my<eye.sy-50 then
        bdrag:net_buy(x,y)
      end
      bdrag=nil
    end
    return
  end
  if conn then
    if b=="r" then
      local dev=get_device(x,y)
      if not dev then
        conn=nil
        return
      end
      if conn==dev then
        if conn.pl==ME then
          menu=conn.menu
        end
        conn=nil
        return
      end
      if kshift then
        conn:net_unlink(dev)
      else
        conn:net_connect(dev)
      end
      conn=nil
    end
    return
  end
end

function main_keypressed(k)
  if k=="lshift" or k=="rshift" then
    kshift=true
    return
  end
  if k=="escape" then
    bdev=nil
    return
  end
  if k=="1" or k=="kp1" then
    bdev=huddevs[1]
    return
  end
  if k=="2" or k=="kp2" then
    bdev=huddevs[2]
    return
  end
  if k=="3" or k=="kp3" then
    bdev=huddevs[3]
    return
  end
  if k=="4" or k=="kp4" then
    bdev=huddevs[4]
    return
  end
  if k=="w" or k=="up" then
    if scroll.y<0 then
      scroll.y=0
    end
    scroll.ky=1
  end
  if k=="s" or k=="down" then
    if scroll.y>0 then
      scroll.y=0
    end
    scroll.ky=-1
  end
  if k=="a" or k=="left" then
    if scroll.x<0 then
      scroll.x=0
    end
    scroll.kx=1
  end
  if k=="d" or k=="right" then
    if scroll.x>0 then
      scroll.x=0
    end
    scroll.kx=-1
  end
  scroll.run=scroll.kx~=0 or scroll.ky~=0 or scroll.ks~=0
end

function main_keyreleased(k)
  if k=="lshift" or k=="rshift" then
    kshift=false
    return
  end
  if k=="w" or k=="up" then
    scroll.ky=0
  end
  if k=="s" or k=="down" then
    scroll.ky=0
  end
  if k=="a" or k=="left" then
    scroll.kx=0
  end
  if k=="d" or k=="right" then
    scroll.kx=0
  end
end

local function draw_hud()
  graph.setColor(0,0,96)
  graph.setLine(1,"rough")
  graph.rectangle("fill",0,eye.sy-50,eye.sx-1,eye.sy-1)
  graph.setColor(64,64,192)
  graph.line(0,eye.sy-50,eye.sx-1,eye.sy-50)
  for i,v in ipairs(huddevs) do
    v:draw_sym()
  end
  graph.setColor(255,255,255)
  graph.print(string.format("Cash: %d",ME.cash),eye.sx-100,eye.sy-40)
  graph.print(string.format("Pkts: %d",ME.pkts),eye.sx-100,eye.sy-20)
  if hover then
    graph.print(string.format("Price: %d",hover.price),eye.sx-200,eye.sy-40)
    graph.print(string.format("Health: %d",hover.maxhealth),eye.sx-200,eye.sy-20)
  end
  if hint and hint.pl and hint.pl.name then
    graph.print(hint.pl.name,msx,msy+17)
  end
end

local ls={0x0f0f,0x1e1e,0x3c3c,0x7878,0xf0f0,0xe1e1,0xc3c3,0x8787}
local lsi=1
function main_draw()
  graph.push()
  graph.translate(eye.cx,eye.cy)
  graph.scale(eye.s)
  graph.translate(eye.vx,eye.vy)
  graph.setScissor(0,0,eye.sx-1,eye.sy-51)
  graph.setLineStipple(ls[lsi])
  for k,o in pairs(links) do
    o:draw()
  end
  graph.setLineStipple()
  if eye.s>0.4 then
    for k,o in pairs(packets) do
      o:draw()
    end
  end
  for k,o in pairs(devices) do
    o:draw()
  end
  if conn then
    if conn.deleted then
      conn=nil
    else
      if kshift then
        local vx,vy=mox-conn.x,moy-conn.y
        local len=math.sqrt(vx*vx+vy*vy)
        if len>240 then
          graph.setColor(150,0,0)
        else
          graph.setColor(255,0,0)
        end
        graph.setLineWidth(1,"rough")
        graph.line(conn.x,conn.y,mox,moy)
      else
        local vx,vy=mox-conn.x,moy-conn.y
        local len=math.sqrt(vx*vx+vy*vy)
        if len>240 then
          graph.setColor(150,150,150)
        else
          graph.setColor(255,255,255)
        end
        graph.setLineWidth(1,"rough")
        graph.line(conn.x,conn.y,mox,moy)
      end
    end
  end
  if drag then
    if drag.deleted then
      drag=nil
    else
      drag:drag(mox,moy)
    end
  end
  if bdrag then
    bdrag:drag(mox,moy)
  end
  if bdev then
    bdev:drag(mox,moy)
  end
  -- hud display
  graph.pop()
  graph.setScissor()
  draw_hud()
  if menu then
    menu:draw()
  end
end

local flow_dt=0
function main_update(dt)
  dtime=dt
  msx,msy=love.mouse.getPosition()
  mox=msx/eye.s-eye.x
  moy=msy/eye.s-eye.y
  scroll.dt=scroll.dt+dt
  if scroll.dt>=0.02 then
    eye.scroll()
    scroll.dt=scroll.dt-0.02
    if scroll.dt>0.02 then
      scroll.dt=0.02
    end
  end
  hover_dt=hover_dt+dt
  if hover_dt>=0.1 then
    hover_dt=0
    if msy>eye.sy-50 then
      hint=nil
      hover=get_buydev(msx,msy)
    else
      hover=nil
      if eye.s<0.6 then
        hint=get_enemydev(mox,moy)
      else
        hint=nil
      end
    end
  end
  flow_dt=flow_dt+dt
  if flow_dt>=0.2 then
    lsi=lsi>7 and 1 or lsi+1
    flow_dt=0
    for k,p in pairs(packets) do
      packets:del(p)
      if p.pl==ME then
        ME.pkts=ME.pkts-1
      end
    end
  elseif flow_dt>=0.05 then
    lsi=lsi>7 and 1 or lsi+1
    for k,p in pairs(packets) do
      if p:flow(flow_dt) then
        packets:del(p)
      end
    end
    flow_dt=flow_dt-0.05
  end
end

function main_quit()
  net_close()
end

function love.run()
  love.load()
  local dt=0

  -- init
  while true do
    if love.timer then
      love.timer.step()
      dt=love.timer.getDelta()
    end
    if love.update then
      love.update(dt)
    end
    if love.graphics then
      love.graphics.clear()
      love.draw()
    end
    if love.event then
      for e,a,b,c in love.event.poll() do
        if e=="q" then
          if love.quit then
            love.quit()
          end
          if love.audio then
            love.audio.stop()
          end
          return
        end
        love.handlers[e](a,b,c)
      end
    end
    if love.graphics then
      love.graphics.present()
    end
    if net_sync() then
      break
    end
  end

  if ME then
    love.draw=main_draw
    love.update=main_update
    love.quit=main_quit
    love.keypressed=main_keypressed
    love.keyreleased=main_keyreleased
    love.mousepressed=main_mousepressed
    love.mousereleased=main_mousereleased
  else
    love.event.push("q")
  end

  -- main
  while true do
    if love.timer then
      love.timer.step()
      dt=love.timer.getDelta()
    end
    if love.update then
      love.update(dt)
    end
    if love.graphics then
      love.graphics.clear()
      love.draw()
    end
    if love.event then
      for e,a,b,c in love.event.poll() do
        if e=="q" then
          if love.quit then
            love.quit()
          end
          if love.audio then
            love.audio.stop()
          end
          return
        end
        love.handlers[e](a,b,c)
      end
    end
    if love.graphics then
      love.graphics.present()
    end
    net_proc()
  end
end

local function set_cl_fonts(imgfont)
  local function set_alpha(x,y,r,g,b,a)
    if r==0 and g==0 and b==0 then
      return 0,0,0,0
    end
    return r,g,b,255
  end
  imgfont:mapPixel(set_alpha)
  local img
  img=love.image.newImageData(16,16)
  img:paste(imgfont,0,0,0,8,16,16)
  devcl.G.__members.img=graph.newImage(img)
  img=love.image.newImageData(16,16)
  img:paste(imgfont,0,0,16,8,16,16)
  devcl.R.__members.img=graph.newImage(img)
  img=love.image.newImageData(16,16)
  img:paste(imgfont,0,0,32,8,16,16)
  devcl.F.__members.img=graph.newImage(img)
  img=love.image.newImageData(16,16)
  img:paste(imgfont,0,0,48,8,16,16)
  devcl.D.__members.img=graph.newImage(img)
end

local function reconf()
  if love.filesystem.exists("netwars.cfg") then
    local chunk=love.filesystem.load("netwars.cfg")
    return chunk()
  end
  local data="return {\n"
  data=data.."width="..graph.getWidth()..";\n"
  data=data.."height="..graph.getHeight()..";\n"
  data=data.."}\n"
  love.filesystem.write("netwars.cfg",data)
  return nil
end

function love.load()
  local t=reconf()
  if t then
    graph.setMode(t.width,t.height)
  end
  eye.sx=graph.getWidth()
  eye.sy=graph.getHeight()
  eye.cx=eye.sx/2
  eye.cy=eye.sy/2
  eye.x=eye.vx+eye.cx/eye.s
  eye.y=eye.vy+eye.cy/eye.s
  graph.setBackgroundColor(0,0,0)
  local imgfont=love.image.newImageData("imgs/font.png")
  set_cl_fonts(imgfont)
  for k,v in pairs(devcl) do
    o=v:new(nil,0,eye.sy-25)
    o.hud=true
    buydevs:add(o)
  end
  local devs={"G","R","F","D"}
  local x=25
  for i,v in ipairs(devs) do
    for k,o in pairs(buydevs) do
      if o.cl==v then
        huddevs[i]=o
        o.x=x
        x=x+40
      end
    end
  end
  love.draw=init_draw
  love.update=init_update
  love.keypressed=init_keypressed
end
