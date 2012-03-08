-- vim:et

require "class"
require "menu"
require "devices"

graph=love.graphics
dtime=0
mrx,mry=0,0
mox,moy=0,0

eye={vx=0,vy=0,si=4,s=1.0}
scroll={
dt=0,run=false;
x=0,y=0,s=3,ks=0,dx=0,dy=0,kx=0,ky=0;
}

vec={}
function vec.len(x1,y1,x2,y2)
  local tx,ty=x2-x1,y2-y1
  return math.sqrt(tx*tx+ty*ty)
end

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

devices=list()
generators=list()
links=list()
packets=list()

drag=nil
hover=nil
hover_dt=0
conn=nil
conn_dt=0
menu=nil

function mn_dev_conn(d)
  conn=d
end

function mn_dev_del(d)
end

function love.keypressed(k)
  if k=="escape" then
    love.event.push("q")
    return
  end
  if k=="w" then
    if scroll.y<0 then
      scroll.y=0
    end
    scroll.ky=1
  end
  if k=="s" then
    if scroll.y>0 then
      scroll.y=0
    end
    scroll.ky=-1
  end
  if k=="a" then
    if scroll.x<0 then
      scroll.x=0
    end
    scroll.kx=1
  end
  if k=="d" then
    if scroll.x>0 then
      scroll.x=0
    end
    scroll.kx=-1
  end
  scroll.run=scroll.kx~=0 or scroll.ky~=0 or scroll.ks~=0
end

function love.keyreleased(k)
  if k=="w" then
    scroll.ky=0
  end
  if k=="s" then
    scroll.ky=0
  end
  if k=="a" then
    scroll.kx=0
  end
  if k=="d" then
    scroll.kx=0
  end
end

local function get_device(x,y)
  for o in devices:iter() do
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
    if menu then
      menu:click()
      menu=nil
      return
    end
    if conn then
      local d=get_device(x,y)
      if d then
        conn:connect(d)
      end
      conn=nil
      return
    end
    drag=get_device(x,y)
    return
  end
  if b=="r" and not menu then
    local d=get_device(x,y)
    if d and d.menu then
      menu=d.menu
    end
    return
  end
end

function love.mousereleased(mx,my,mb)
  local x,y=mx/eye.s-eye.x,my/eye.s-eye.y
  if mb=="l" then
    drag=nil
    return
  end
end

function love.load()
  eye.sx=graph.getWidth()
  eye.sy=graph.getHeight()
  eye.cx=eye.sx/2
  eye.cy=eye.sy/2
  eye.x=eye.vx+eye.cx/eye.s
  eye.y=eye.vy+eye.cy/eye.s
  graph.setBackgroundColor(0,0,0)
  o=Generator:new(0,0)
  devices:add(o)
  generators:add(o)
  o=Generator:new(-50,0)
  devices:add(o)
  generators:add(o)
  o=Generator:new(-30,-30)
  devices:add(o)
  generators:add(o)
end

function love.draw()
  graph.push()
  graph.translate(eye.cx,eye.cy)
  graph.scale(eye.s)
  graph.translate(eye.vx,eye.vy)
  for o in links:iter() do
    o:draw()
  end
  for o in packets:iter() do
    o:draw()
  end
  for o in devices:iter() do
    o:draw()
  end
  if conn then
    graph.setColor(255,255,255)
    graph.setLineWidth(1,"rough")
    graph.line(conn.x,conn.y,mox,moy)
  end
  graph.pop()
  if menu then
    menu:draw()
  end
  graph.setColor(255,255,255)
  graph.print(string.format("fps: %f",love.timer.getFPS()),10,10)
  if hover then
    graph.print(string.format("x=%f,y=%f",hover.x,hover.y),10,20)
  end
end

local emit_dt=0
local step_dt=0
function love.update(dt)
  dtime=dt
  scroll.dt=scroll.dt+dt
  mrx,mry=love.mouse.getPosition()
  mox=mrx/eye.s-eye.x
  moy=mry/eye.s-eye.y
  if scroll.dt>=0.02 then
    eye.scroll()
    scroll.dt=0
  end
  if drag then
    drag:move(mox,moy)
  end
  hover_dt=hover_dt+dt
  if hover_dt>=0.1 then
    hover=get_device(mox,moy)
    hover_dt=0
  end
  step_dt=step_dt+dt
  if step_dt>=0.05 then
    for o in packets:iter() do
      o:step(step_dt)
    end
    step_dt=0
  end
  emit_dt=emit_dt+dt
  if emit_dt>=1 then
    emit_dt=0
    for o in generators:iter() do
      o:emit()
    end
  end
end
