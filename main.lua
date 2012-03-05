require "class"
require "devices"

graph=love.graphics
time=0

eye={x=0,y=0,si=3,s=1.0}
scroll={dt=0,x=0,y=0,s=3,ks=0,dx=0,dy=0,kx=0,ky=0}

function scroll.by()
  eye.x=eye.x+scroll.x
  eye.y=eye.y+scroll.y
  if scroll.kx==0 then
    scroll.x=scroll.x-(scroll.x*0.2)
    if math.abs(scroll.x)<1 then
      scroll.x=0
    end
  else
    if math.abs(scroll.x)<10 then
      scroll.x=scroll.x+(scroll.kx*0.5)
    end
  end
  if scroll.ky==0 then
    scroll.y=scroll.y-(scroll.y*0.2)
    if math.abs(scroll.y)<1 then
      scroll.y=0
    end
  else
    if math.abs(scroll.y)<10 then
      scroll.y=scroll.y+(scroll.ky*0.5)
    end
  end
  if scroll.ks<0 then
    eye.s=eye.s+(scroll.ks/10)
    if eye.s<=scroll.s then
      scroll.ks=0
      eye.s=scroll.s
    end
  end
  if scroll.ks>0 then
    eye.s=eye.s+(scroll.ks/10)
    if eye.s>=scroll.s then
      scroll.ks=0
      eye.s=scroll.s
    end
  end
end

devices=List:new()

function love.keypressed(k)
  if k=="escape" then
    love.event.push("q")
    return
  end
  if k=="w" then
    if scroll.y>0 then
      scroll.y=0
    end
    scroll.ky=-1
  end
  if k=="s" then
    if scroll.y<0 then
      scroll.y=0
    end
    scroll.ky=1
  end
  if k=="a" then
    if scroll.x>0 then
      scroll.x=0
    end
    scroll.kx=-1
  end
  if k=="d" then
    if scroll.x<0 then
      scroll.x=0
    end
    scroll.kx=1
  end
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

function love.mousepressed(x,y,b)
  local s={0.5,0.7,1.0,1.5,3.0}
  if b=="wu" then
    if eye.si<#s then
      scroll.ks=s[eye.si+1]-s[eye.si]
      eye.si=eye.si+1
    end
  end
  if b=="wd" then
    if eye.si>1 then
      scroll.ks=-(s[eye.si]-s[eye.si-1])
      eye.si=eye.si-1
    end
  end
  scroll.s=s[eye.si]
end

function love.load()
  eye.sx=graph.getWidth()
  eye.sy=graph.getHeight()
  eye.cx=eye.sx/2
  eye.cy=eye.sy/2
  graph.setBackgroundColor(0,0,0)
  o=Generator:new(0,0)
  devices:add(o)
  o=Generator:new(-50,0)
  devices:add(o)
  o=Generator:new(-30,-30)
  devices:add(o)
end

function love.draw()
  graph.push()
  graph.translate(eye.x+eye.cx,eye.y+eye.cy)
  graph.scale(eye.s)
  for o in devices:iter() do
    o:draw()
  end
  graph.pop()
  graph.print(string.format("s=%f",eye.s),10,10)
end

function love.update(dt)
  time=time+dt
  scroll.dt=scroll.dt+dt
  if scroll.dt>=0.02 then
    scroll.by()
    scroll.dt=0
  end
end
