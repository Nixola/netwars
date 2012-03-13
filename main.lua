-- vim:et

require "class"
require "menu"
require "devices"
require "devices_gui"
require "client"

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
local hover=nil
local hover_dt=0
local conn=nil
local unlink=nil
local menu=nil
local kshift=false

function mn_dev_conn(d)
  conn=d
end

function mn_dev_unlink(d)
  unlink=d
end

function mn_dev_del(d)
end

function love.keypressed(k)
  if k=="escape" then
    love.event.push("q")
    return
  end
  if k=="lshift" or k=="rshift" then
    kshift=true
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

function love.keyreleased(k)
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
      if o.pl==ME then
        return o
      end
      return nil
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

function love.mousepressed(mx,my,b)
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
  if b=="l" then
    if kshift then
      local dev=get_my_device(x,y)
      if dev then
        dev:net_switch()
      end
      return
    end
    if menu then
      menu=menu:click()
      return
    end
    if conn then
      local d=get_device(x,y)
      if d then
        conn:net_connect(d)
      end
      conn=nil
      return
    end
    if unlink then
      local d=get_device(x,y)
      if d then
        unlink:net_unlink(d)
      end
      unlink=nil
      return
    end
    bdrag=get_buydev(mx,my)
    if bdrag then
      return
    end
    drag=get_my_device(x,y)
    if drag and (drag.online or drag.pc>0) then
      drag=nil
      return
    end
    return
  end
  if b=="r" and (not menu) then
    local d=get_my_device(x,y)
    if d and d.menu then
      menu=d.menu
    end
    return
  end
end

function love.mousereleased(mx,my,mb)
  local x,y=mx/eye.s-eye.x,my/eye.s-eye.y
  if drag and mb=="l" then
    if (not drag.online) and drag.pc<1 then
      drag:net_move(mox,moy)
    end
    drag=nil
    return
  end
  if bdrag and mb=="l" then
    if my<eye.sy-50 then
      bdrag:net_buy(x,y)
    end
    bdrag=nil
    return
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
  img:paste(imgfont,0,0,48,8,16,16)
  devcl.D.__members.img=graph.newImage(img)
end

function love.load()
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
  local devs={"G","R","D"}
  local x=20
  for i,v in ipairs(devs) do
    for k,o in pairs(buydevs) do
      if o.cl==v then
        huddevs[i]=o
        o.x=x
        x=x+40
      end
    end
  end
  net_conn("127.0.0.1",6352)
  if not ME then
    love.event.push("q")
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
end

local ls={0x0f0f,0x1e1e,0x3c3c,0x7878,0xf0f0,0xe1e1,0xc3c3,0x8787}
local lsi=1
function love.draw()
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
  if unlink then
    local vx,vy=mox-unlink.x,moy-unlink.y
    local len=math.sqrt(vx*vx+vy*vy)
    if len>240 then
      graph.setColor(150,0,0)
    else
      graph.setColor(255,0,0)
    end
    graph.setLineWidth(1,"rough")
    graph.line(unlink.x,unlink.y,mox,moy)
  end
  if drag then
    drag:drag(mox,moy)
  end
  if bdrag then
    bdrag:drag(mox,moy)
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
function love.update(dt)
  dtime=dt
  scroll.dt=scroll.dt+dt
  msx,msy=love.mouse.getPosition()
  mox=msx/eye.s-eye.x
  moy=msy/eye.s-eye.y
  if scroll.dt>=0.02 then
    eye.scroll()
    scroll.dt=0
  end
  hover_dt=hover_dt+dt
  if hover_dt>=0.1 then
    hover=get_buydev(msx,msy)
    hover_dt=0
  end
  flow_dt=flow_dt+dt
  if flow_dt>=0.05 then
    lsi=lsi>7 and 1 or lsi+1
    for k,p in pairs(packets) do
      if p:flow(flow_dt) then
        packets:del(p)
      end
    end
    flow_dt=0
  end
end

function love.quit()
  net_close()
  love.timer.sleep(5000)
end

function love.run()
  love.load()

  local dt=0
  local ret
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
