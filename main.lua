require "class"
require "devices"

graph=love.graphics
time=0

eye={vx=0,vy=0,si=4,s=1.0}
scroll={
dt=0,run=false;
x=0,y=0,s=3,ks=0,dx=0,dy=0,kx=0,ky=0}

function eye.in_view(x,y,r)
  local sx=eye.cx/eye.s
  local sy=eye.cy/eye.s
  local tx=math.abs(eye.x-x)
  local ty=math.abs(eye.y-y)
  return tx<sx and ty<sy
end

function scroll.exec()
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

devices=List:new()

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

local drag=nil
local hover=nil
local hover_dt=0

function love.mousepressed(mx,my,b)
  local s={0.3,0.5,0.7,1.0,1.5,3.0}
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
    for o in devices:iter() do
      if o:is_pointed(x,y) then
        drag=o
        break
      end
    end
    return
  end
end

function love.mousereleased(mx,my,mb)
  if mb=="l" then
    drag=nil
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
  o=Generator:new(-50,0)
  devices:add(o)
  o=Generator:new(-30,-30)
  devices:add(o)
end

function love.draw()
  graph.setColor(150,150,150)
  graph.line(100,300,700,300)
  graph.line(400,100,400,500)
  graph.push()
  graph.translate(eye.cx,eye.cy)
  graph.scale(eye.s)
  graph.translate(eye.vx,eye.vy)
  for o in devices:iter() do
    if eye.in_view(o.x,o.y,o.r) then
      o:draw()
    end
  end
  graph.pop()
  graph.setColor(255,255,255)
  graph.print(string.format("s=%f",eye.s),10,10)
  if hover then
    graph.print(string.format("x=%f,y=%f",hover.x,hover.y),10,20)
  end
end

function love.update(dt)
  time=time+dt
  scroll.dt=scroll.dt+dt
  if scroll.dt>=0.02 then
    scroll.exec()
    scroll.dt=0
  end
  local x=love.mouse.getX()/eye.s-eye.x
  local y=love.mouse.getY()/eye.s-eye.y
  if drag then
    drag.x=x
    drag.y=y
  end
  hover_dt=hover_dt+dt
  if hover_dt>=0.1 then
    hover=nil
    for o in devices:iter() do
      if o:is_pointed(x,y) then
        hover=o
        break
      end
    end
    hover_dt=0
  end
end
