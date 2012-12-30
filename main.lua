-- vim:et

require "class"
require "sphash"
require "menu"
require "devices"
require "devices_gui"
require "client"
require "chat"
require "console"
require "init"

CVER=1 -- config version

graph=love.graphics
srvts=0
msx,msy=0,0 -- mouse real (screen) position
omsx,omsy=0,0 -- mouse old real (screen) position
mox,moy=0,0 -- mouse virtual position

eye={vx=0,vy=0,si=5,s=1.0,run=false} -- eyeposition, scale index, scale
scroll={
dt=0,run=false;drag=false;
x=0,y=0,s=3,ks=0,dx=0,dy=0,kx=0,ky=0;
}

function eye.in_view(x,y,...)
  local arg={...}
  local sx=eye.cx/eye.s
  local sy=eye.cy/eye.s
  if #arg==0 then
    local tx=abs(eye.vx+x)
    local ty=abs(eye.vy+y)
    return tx<sx and ty<sy
  end
  if #arg==1 then
    local tx=abs(eye.vx+x)-arg[1]
    local ty=abs(eye.vy+y)-arg[1]
    return tx<sx and ty<sy
  end
  if #arg==2 then
    local tx1=abs(eye.vx+x)
    local ty1=abs(eye.vy+y)
    local tx2=abs(eye.vx+arg[1])
    local ty2=abs(eye.vy+arg[2])
    return tx1<sx and ty1<sy or tx2<sx and ty2<sy
  end
end

function eye.scroll()
  if not scroll.run then
    return
  end
  if scroll.kx==0 then
    scroll.x=scroll.x-(scroll.x*0.2)
    if abs(scroll.x)<1 then
      scroll.x=0
    end
  else
    if abs(scroll.x)<10/eye.s then
      scroll.x=scroll.x+(scroll.kx/eye.s)
    end
  end
  if scroll.ky==0 then
    scroll.y=scroll.y-(scroll.y*0.2)
    if abs(scroll.y)<1 then
      scroll.y=0
    end
  else
    if abs(scroll.y)<10/eye.s then
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
  eye.vx=floor(eye.vx+scroll.x)
  eye.vy=floor(eye.vy+scroll.y)
  eye.x=floor(eye.vx+eye.cx/eye.s)
  eye.y=floor(eye.vy+eye.cy/eye.s)
  scroll.run=scroll.x~=0 or scroll.y~=0 or scroll.ks~=0
end

function eye.set_drag()
  eye.ovx=eye.vx
  eye.ovy=eye.vy
  omsx,omsy=msx,msy
  scroll.drag=true
end

function eye.drag()
  eye.vx=floor(eye.ovx-((omsx-msx)/eye.s))
  eye.vy=floor(eye.ovy-((omsy-msy)/eye.s))
  eye.x=floor(eye.vx+eye.cx/eye.s)
  eye.y=floor(eye.vy+eye.cy/eye.s)
end

ME=nil
players=ctable()
devices=ctable()
links=storage()
packets=storage()
shots=storage()
hash=sphash(200)

buydevs={}
local buyidx=2

local drag=nil
local bdrag=nil
local bdev=nil
local move=nil
local targ=nil
local hover=nil
local hint=nil
local hover_dt=0
local conn=nil
local menu=nil
local kshift=false
local kctrl=false
local scoreboard=false

local function get_device(x,y)
  local t=hash:get(x,y)
  for _,o in pairs(t) do
    if o:is_pointed(x,y) then
      return o
    end
  end
  return nil
end

local function get_my_dev(x,y)
  local t=hash:get(x,y)
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

local function get_enemy_dev(x,y)
  local t=hash:get(x,y)
  for _,o in pairs(t) do
    if o:is_pointed(x,y) and o.pl~=ME then
      return o
    end
  end
  return nil
end

function main_mousepressed(mx,my,b)
  local s={0.2,0.3,0.45,0.67,1.0,1.5}
  local x,y=mx/eye.s-eye.x,my/eye.s-eye.y
  if b=="wu" then
    if eye.si<#s then
      scroll.ks=abs(eye.s-s[eye.si+1])
      eye.si=eye.si+1
    end
    scroll.s=s[eye.si]
    scroll.run=scroll.ks~=0
    return
  end
  if b=="wd" then
    if eye.si>1 then
      scroll.ks=-abs(eye.s-s[eye.si-1])
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
    local obj=get_my_dev(x,y)
    if obj then
      if kshift then
        obj:net_switch()
        return
      end
      if kctrl then
        obj:net_upgrade()
        return
      end
      if not obj.nomove and not obj.online and obj.pc<1 then
        drag=obj
      end
      return
    end
    eye.set_drag()
    return
  end
  if b=="r" then
    local obj=get_device(x,y)
    if obj and (obj.pl==ME or obj.cl=="G") then
      if obj.set_targ then
        targ=obj
      else
        conn=obj
      end
    end
    return
  end
end

function main_mousereleased(mx,my,b)
  local x,y=mx/eye.s-eye.x,my/eye.s-eye.y
  if scroll.drag then
    if b=="l" then
      scroll.drag=false
    end
    return
  end
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
  if move then
    if b=="l" then
      move:net_move(x,y)
      move=nil
    end
    return
  end
  if targ then
    if b=="r" then
      local dev=get_device(x,y)
      if not dev then
        targ:set_targ(nil)
        targ=nil
        return
      end
      if targ==dev then
        if targ.pl==ME then
          menu=targ.menu
        end
        targ=nil
        return
      end
      targ:set_targ(dev)
      targ=nil
    end
    return
  end
end

function main_keypressed(key,ch)
  if chat.input then
    chat.input=chat.keypressed(key,ch)
    return
  end
  if console.input then
    console.input=console.keypressed(key,ch)
    return
  end
  if key=="lshift" or key=="rshift" then
    kshift=true
    return
  end
  if key=="lctrl" or key=="rctrl" then
    kctrl=true
    return
  end
  if key=="escape" then
    bdev=nil
    return
  end
  if key=="tab" then
    scoreboard=true
    return
  end
  if key=="return" then
    chat.input=true
    return
  end
  if key=="`" then
    console.input=true
    return
  end
  if key==" " then
    if ME.started then
      buyidx=buyidx<1 and buyidx+1 or 1
    else
      buyidx=2
    end
    return
  end
  if key=="1" or key=="kp1" then
    bdev=buydevs[buyidx][1]
    return
  end
  if key=="2" or key=="kp2" then
    bdev=buydevs[buyidx][2]
    return
  end
  if key=="3" or key=="kp3" then
    bdev=buydevs[buyidx][3]
    return
  end
  if key=="4" or key=="kp4" then
    bdev=buydevs[buyidx][4]
    return
  end
  if key=="5" or key=="kp5" then
    bdev=buydevs[buyidx][5]
    return
  end
  if key=="6" or key=="kp6" then
    bdev=buydevs[buyidx][6]
    return
  end
  if key=="w" or key=="up" then
    if scroll.y<0 then
      scroll.y=0
    end
    scroll.ky=1
  end
  if key=="s" or key=="down" then
    if scroll.y>0 then
      scroll.y=0
    end
    scroll.ky=-1
  end
  if key=="a" or key=="left" then
    if scroll.x<0 then
      scroll.x=0
    end
    scroll.kx=1
  end
  if key=="d" or key=="right" then
    if scroll.x>0 then
      scroll.x=0
    end
    scroll.kx=-1
  end
  scroll.run=scroll.kx~=0 or scroll.ky~=0 or scroll.ks~=0
end

function main_keyreleased(key)
  if key=="lshift" or key=="rshift" then
    kshift=false
    return
  end
  if key=="lctrl" or key=="rctrl" then
    kctrl=false
    return
  end
  if key=="tab" then
    scoreboard=false
    return
  end
  if key=="w" or key=="up" then
    scroll.ky=0
  end
  if key=="s" or key=="down" then
    scroll.ky=0
  end
  if key=="a" or key=="left" then
    scroll.kx=0
  end
  if key=="d" or key=="right" then
    scroll.kx=0
  end
end

function main_started()
  ME.started=true
  buyidx=1
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
  if hint and hint.pl and hint.pl~=ME and hint.pl.name then
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
  local h=hash:get(x1,y1,x2,y2)
  if love._ver<=72 then
    graph.setLineStipple(ls[lsi])
  end
  for _,o in pairs(links) do
    if h[o.dev1] or h[o.dev2] then
      o:draw()
    end
  end
  if love._ver<=72 then
    graph.setLineStipple()
  end
  if eye.s>0.4 then
    for _,o in pairs(packets) do
      if h[o.dev1] or h[o.dev2] then
        o:draw()
      end
    end
  end
  -- draw devices
  for _,o in pairs(h) do
    o:draw()
  end
  if drag or bdrag or bdev then
    local d=drag or bdrag or bdev
    for _,o in pairs(h) do
      if o~=d then
        o:draw_cborder()
      end
    end
  end
  -- draw shots
  if eye.s>0.4 then
    for _,o in pairs(shots) do
      if h[o.obj1] or h[o.obj2] then
        o:draw()
      end
    end
  end
  -- draw commands
  local cmd=false
  if conn then
    cmd=true
    if conn.deleted then
      conn=nil
    else
      if kshift then
        graph.setColor(255,0,0)
        graph.setLine(1,"rough")
        graph.line(conn.x,conn.y,mox,moy)
      else
        local tx,ty=mox-conn.x,moy-conn.y
        local len=floor(sqrt(tx*tx+ty*ty))
        conn:draw_rng(x,y)
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
    cmd=true
    if drag.deleted then
      drag=nil
    else
      drag:drag(mox,moy)
    end
  end
  if bdrag then
    cmd=true
    bdrag:drag(mox,moy)
  end
  if bdev then
    cmd=true
    bdev:drag(mox,moy)
  end
  if move then
    local x,y=move:calc_xy(mox,moy)
    cmd=true
    move:draw_rng(x,y)
    graph.setColor(255,255,255)
    graph.setLine(1,"rough")
    graph.line(move.x,move.y,x,y)
  end
  if targ then
    cmd=true
    targ:draw_rng()
    graph.setColor(0,0,255)
    graph.setLine(1,"rough")
    graph.line(targ.x,targ.y,mox,moy)
  end
  if not cmd and hint and hint.pl==ME then
    hint:draw_rng()
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
  console.draw()
end

local flow_dt=0

function devs_proc(dt)
  for _,o in pairs(devices) do
    if o.pl==ME then
      if o.targ and o.targ.deleted then
        o.targ=nil
      end
      if not o.deleted and o.online and o.logic then
        o.dt=o.dt+dt
        if o.dt>=2.0 then
          o.dt=o.dt-2.0
          o:logic()
        end
      else
        o.dt=0
      end
    end
  end
end

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
  if scroll.drag then
    eye.drag()
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
        hint=get_enemy_dev(mox,moy)
      else
        hint=get_my_dev(mox,moy)
      end
    end
  end
  for _,p in pairs(packets) do
    if p:flow(dt) then
      p:delete()
      packets:del(p)
    end
  end
  for _,s in pairs(shots) do
    if s:flow(dt) then
      shots:del(s)
    end
  end
  devs_proc(dt)
  flow_dt=flow_dt+dt
  if flow_dt>=0.05 then
    lsi=lsi>7 and 1 or lsi+1
    flow_dt=flow_dt-0.05
  end
  console.update(dt)
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
  d_cl.G.img=graph.newImage(img)
  img=love.image.newImageData(16,16)
  img:paste(imgfont,0,0,16,8,16,16)
  d_cl.R.img=graph.newImage(img)
  img=love.image.newImageData(16,16)
  img:paste(imgfont,0,0,32,8,16,16)
  d_cl.B.img=graph.newImage(img)
  img=love.image.newImageData(16,16)
  img:paste(imgfont,0,0,48,8,16,16)
  d_cl.V.img=graph.newImage(img)
  img=love.image.newImageData(16,16)
  img:paste(imgfont,0,0,64,8,16,16)
  d_cl.T.img=graph.newImage(img)
end


function love.load()
  -- determine love version hacks
  if type(love._version)=="string" then
    local tmp=str_split(love._version,".")
    love._ver=tonumber(tmp[2])*10+tonumber(tmp[3])
  else
    love._ver=love._version
  end
  if load_conf() then
    set_graph()
  end
  init_graph()
  local imgfont=love.image.newImageData("imgs/font.png")
  set_cl_fonts(imgfont)
  init_gui()
  love.draw=init_draw
  love.update=init_update
  love.keypressed=init_keypressed
end
