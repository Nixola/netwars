-- vim:et

require "class"
require "sphash"
require "menu"
require "devices"
require "devices_gui"
require "client"
require "init"
require "chat"

CVER=1 -- config version

graph=love.graphics
srvts=0
msx,msy=0,0 -- mouse real (screen) position
mox,moy=0,0 -- mouse virtual position

eye={vx=0,vy=0,si=4,s=1.0} -- eyeposition, scale index, scale
scroll={
dt=0,run=false;
x=0,y=0,s=3,ks=0,dx=0,dy=0,kx=0,ky=0;
}

function eye.in_view(x,y,...)
  local arg={...}
  local sx=eye.cx/eye.s
  local sy=eye.cy/eye.s
  if #arg==0 then
    local tx=math.abs(eye.vx+x)
    local ty=math.abs(eye.vy+y)
    return tx<sx and ty<sy
  end
  if #arg==1 then
    local tx=math.abs(eye.vx+x)-arg[1]
    local ty=math.abs(eye.vy+y)-arg[1]
    return tx<sx and ty<sy
  end
  if #arg==2 then
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
  eye.vx=math.floor(eye.vx+scroll.x)
  eye.vy=math.floor(eye.vy+scroll.y)
  eye.x=math.floor(eye.vx+eye.cx/eye.s)
  eye.y=math.floor(eye.vy+eye.cy/eye.s)
  scroll.run=scroll.x~=0 or scroll.y~=0 or scroll.ks~=0
end

ME=nil
players=ctable()
devices=ctable()
units=ctable()
links=storage()
packets=storage()
shots=storage()
dhash=sphash(200)
uhash=sphash(100)

local buydevs={}
local buyidx=3

local drag=nil
local bdrag=nil
local bdev=nil
local umove=nil
local utarg=nil
local hover=nil
local hint=nil
local hover_dt=0
local conn=nil
local menu=nil
local kshift=false
local scoreboard=false

local function get_device(x,y)
  local t=dhash:get(x,y)
  for _,o in pairs(t) do
    if o:is_pointed(x,y) then
      return o
    end
  end
  return nil
end

local function get_my_device(x,y)
  local t=dhash:get(x,y)
  for _,o in pairs(t) do
    if o:is_pointed(x,y) and o.pl==ME then
      return o
    end
  end
  return nil
end

local function get_my_unit(x,y)
  local t=uhash:get(x,y)
  for _,o in pairs(t) do
    if o:is_pointed(x,y) and o.pl==ME then
      return o
    end
  end
  return nil
end

local function get_buydev(x,y)
  for _,o in pairs(buydevs[buyidx]) do
    if o:is_pointed(x,y) then
      return o
    end
  end
  return nil
end

local function get_enemydev(x,y)
  for _,o in pairs(buydevs[buyidx]) do
    if o:is_pointed(x,y) then
      return o
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
    local obj=get_my_unit(x,y)
    if obj then
      umove=obj
      return
    end
    obj=get_my_device(x,y)
    if obj then
      if kshift then
        obj:net_switch()
        return
      end
      if (not obj.nomove) and (not obj.online) and obj.pc<1 then
        drag=obj
      end
    end
    return
  end
  if b=="r" then
    local obj=get_my_unit(x,y)
    if obj then
      utarg=obj
      return
    end
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
  if umove then
    if b=="l" then
      umove:net_move(x,y)
      umove=nil
    end
    return
  end
  if utarg then
    if b=="r" then
      local obj=get_device(x,y)
      utarg:net_targ(obj)
      utarg=nil
    end
    return
  end
end

function main_keypressed(k,ch)
  if chat.input then
    chat.input=chat.keypressed(k,ch)
    return
  end
  if k=="lshift" or k=="rshift" then
    kshift=true
    return
  end
  if k=="escape" then
    bdev=nil
    return
  end
  if k=="tab" then
    scoreboard=true
    return
  end
  if k=="return" then
    chat.input=true
    return
  end
  if k=="`" then
    chat.console=true
    chat.input=true
    return
  end
  if k==" " then
    buyidx=buyidx<2 and buyidx+1 or 1
    return
  end
  if k=="1" or k=="kp1" then
    bdev=buydevs[buyidx][1]
    return
  end
  if k=="2" or k=="kp2" then
    bdev=buydevs[buyidx][2]
    return
  end
  if k=="3" or k=="kp3" then
    bdev=buydevs[buyidx][3]
    return
  end
  if k=="4" or k=="kp4" then
    bdev=buydevs[buyidx][4]
    return
  end
  if k=="5" or k=="kp5" then
    bdev=buydevs[buyidx][5]
    return
  end
  if k=="6" or k=="kp6" then
    bdev=buydevs[buyidx][6]
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
  if k=="tab" then
    scoreboard=false
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
  for _,v in ipairs(buydevs[buyidx]) do
    v:draw_sym()
  end
  graph.setColor(255,255,255)
  graph.print(string.format("Cash: %d/%d",ME.cash,ME.maxcash),eye.sx-150,eye.sy-40)
  graph.print(string.format("Pkts: %d",ME.pkts),eye.sx-150,eye.sy-20)
  if hover or bdrag or bdev then
    local d=hover or bdrag or bdev
    graph.print(string.format("Price: %d",d.price),eye.sx-250,eye.sy-40)
    graph.print(string.format("Health: %d",d.maxhealth),eye.sx-250,eye.sy-20)
  end
  if hint and hint.pl and hint.pl.name then
    graph.print(hint.pl.name,msx,msy+17)
  end
end

local function draw_scoreboard()
  local padding = 16
  local player_count = 0
  for _,v in pairs(players) do
    player_count = player_count + 1
  end
  local x,y=eye.cx-200,eye.cy-(padding*(4+player_count))/2
  graph.setColor(0,0,120,192)
  graph.rectangle("fill",x,y,400,padding*(4+player_count))

  graph.print("Name",x+padding,y+padding)
  graph.print("Cash",x+200+padding,y+padding)
  graph.print("Devices",x+300+padding,y+padding)
  
  local abs_index = 0
  for i,v in pairs(players) do
    abs_index = abs_index + 1
    graph.print(v.name,x+padding,y+(abs_index+2)*padding)
    graph.print(v.cash,x+200+padding,y+(abs_index+2)*padding)
    graph.print(v.devcnt,x+300+padding,y+(abs_index+2)*padding)
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
  local sx=eye.cx/eye.s
  local sy=eye.cy/eye.s
  local x1,y1=-eye.vx-sx,-eye.vy-sy
  local x2,y2=-eye.vx+sx,-eye.vy+sy
  local hd=dhash:get(x1,y1,x2,y2)
  local hu=uhash:get(x1,y1,x2,y2)
  graph.setLineStipple(ls[lsi])
  for _,o in pairs(links) do
    if hd[o.dev1] or hd[o.dev2] then
      o:draw()
    end
  end
  graph.setLineStipple()
  if eye.s>0.4 then
    for _,o in pairs(packets) do
      if hd[o.dev1] or hd[o.dev2] then
        o:draw()
      end
    end
  end
  -- draw devices
  for _,o in pairs(hd) do
    o:draw()
  end
  if drag or bdrag or bdev then
    local d=drag or bdrag or bdev
    if buyidx==1 then
      for _,o in pairs(hd) do
        if o~=d then
          o:draw_cborder()
        end
      end
    end
  end
  -- draw units
  for _,o in pairs(hu) do
    o:draw()
  end
  -- draw shots
  if eye.s>0.4 then
    for _,o in pairs(shots) do
      ok1=o.obj1.isdev and hd[o.obj1] or hu[o.obj1]
      ok1=o.obj2.isdev and hd[o.obj2] or hu[o.obj2]
      if ok1 or ok2 then
        o:draw()
      end
    end
  end
  -- draw commands
  if conn then
    if conn.deleted then
      conn=nil
    else
      if kshift then
        graph.setColor(255,0,0)
        graph.setLine(1,"rough")
        graph.line(conn.x,conn.y,mox,moy)
      else
        local tx,ty=mox-conn.x,moy-conn.y
        local len=math.floor(math.sqrt(tx*tx+ty*ty))
        if len>LINK then
          graph.setColor(128,128,128)
        else
          graph.setColor(255,255,255)
        end
        graph.setLine(1,"rough")
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
  if umove then
    local x,y=umove:calc_xy(mox,moy)
    graph.setColor(255,255,255)
    graph.setLine(1,"rough")
    graph.line(umove.x,umove.y,x,y)
  end
  if utarg then
    graph.setColor(0,0,255)
    graph.setLine(1,"rough")
    graph.line(utarg.x,utarg.y,mox,moy)
  end
  -- hud display
  graph.pop()
  graph.setScissor()
  draw_hud()
  if menu then
    menu:draw()
  end
  if scoreboard then
    draw_scoreboard()
  end
  chat.draw()
end

local flow_dt=0
function main_update(dt)
  net_proc()
  srvts=srvts+dt
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
  for _,p in pairs(packets) do
    if p:flow(dt) then
      p:delete()
      packets:del(p)
    end
  end
  for _,o in pairs(units) do
    o:step(dt)
    if o.targ and o.targ.deleted then
      o.targ=nil
    end
  end
  for _,s in pairs(shots) do
    if s:flow(dt) then
      shots:del(s)
    end
  end
  flow_dt=flow_dt+dt
  if flow_dt>=0.05 then
    lsi=lsi>7 and 1 or lsi+1
    flow_dt=flow_dt-0.05
  end
  chat.update(dt)
end

function main_quit()
  net_close()
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
  d_cl.G.__members.img=graph.newImage(img)
  img=love.image.newImageData(16,16)
  img:paste(imgfont,0,0,16,8,16,16)
  d_cl.R.__members.img=graph.newImage(img)
  img=love.image.newImageData(16,16)
  img:paste(imgfont,0,0,32,8,16,16)
  d_cl.F.__members.img=graph.newImage(img)
  img=love.image.newImageData(16,16)
  img:paste(imgfont,0,0,48,8,16,16)
  d_cl.V.__members.img=graph.newImage(img)
  img=love.image.newImageData(16,16)
  img:paste(imgfont,0,0,64,8,16,16)
  d_cl.T.__members.img=graph.newImage(img)
  img=love.image.newImageData(8,8)
  img:paste(imgfont,0,0,4,36,8,8)
  u_cl.e.__members.img=graph.newImage(img)
  img=love.image.newImageData(8,8)
  img:paste(imgfont,0,0,20,36,8,8)
  u_cl.t.__members.img=graph.newImage(img)
  img=love.image.newImageData(8,8)
  img:paste(imgfont,0,0,36,36,8,8)
  u_cl.s.__members.img=graph.newImage(img)
  img=love.image.newImageData(8,8)
  img:paste(imgfont,0,0,52,36,8,8)
  u_cl.c.__members.img=graph.newImage(img)
end

local function reconf()
  if love.filesystem.exists("netwars.cfg") then
    local chunk=love.filesystem.load("netwars.cfg")
    local t=chunk()
    if t.ver==CVER then
      return t
    end
  end
  local f=love.filesystem.newFile("netwars.cfg")
  f:open("w")
  f:write("return {\n")
  f:write(string.format("ver=%d;\n",CVER))
  f:write(string.format("graph_width=%d;\n",graph.getWidth()))
  f:write(string.format("graph_height=%d;\n",graph.getHeight()))
  f:write("chat_timeout=5.0;\n")
  f:write("}\n")
  f:close()
  return nil
end

function love.load()
  local t=reconf()
  if t then
    graph.setMode(t.graph_width,t.graph_height)
    chat.timeout=t.chat_timeout
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
  local o
  local cl={"R","T","F","V"}
  local x=25
  local objs={}
  for i,v in ipairs(cl) do
    o=d_cl[v]:new(nil,x,eye.sy-25)
    o.hud=true
    objs[i]=o
    x=x+40
  end
  buydevs[1]=objs
  cl={"t","s","e"}
  x=25
  objs={}
  for i,v in ipairs(cl) do
    o=u_cl[v]:new(nil,x,eye.sy-25)
    o.hud=true
    objs[i]=o
    x=x+40
  end
  buydevs[2]=objs
  cl={"c"}
  x=25
  objs={}
  for i,v in ipairs(cl) do
    o=u_cl[v]:new(nil,x,eye.sy-25)
    o.hud=true
    objs[i]=o
    x=x+40
  end
  buydevs[3]=objs
  love.draw=init_draw
  love.update=init_update
  love.keypressed=init_keypressed
end
