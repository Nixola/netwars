-- vim:et

require "readline"

local readline=Readline:new(15)
local nick=""
local addr=""
local init_st=1
net_err=nil
repiter=nil
replay=false
conf={}

function save_conf()
  local f=love.filesystem.newFile("netwars.cfg")
  f:open("w")
  f:write("return {\n")
  for k,v in pairs(conf) do
    if type(v)=="number" then
      f:write(string.format("%s=%s;\n",k,v))
    end
    if type(v)=="string" then
      f:write(string.format("%s=\"%s\";\n",k,v))
    end
  end
  f:write("}\n")
  f:close()
end

function load_conf()
  if love.filesystem.exists("netwars.cfg") then
    local chunk=love.filesystem.load("netwars.cfg")
    local t=chunk()
    if t.ver==CVER then
      conf=t
      return true
    end
  end
  conf.ver=CVER
  conf.graph_width=graph.getWidth()
  conf.graph_height=graph.getHeight()
  conf.chat_timeout=5.0
  save_conf()
  chat.timeout=conf.chat_timeout
  return false
end

function set_graph(fullscreen)
  graph.setMode(conf.graph_width,conf.graph_height, fullscreen)
end

function init_graph()
  if love._ver<=72 then
    graph.setFont(12)
  else
    local font=graph.newFont(12)
    graph.setFont(font)
  end
  eye.sx=graph.getWidth()
  eye.sy=graph.getHeight()
  eye.cx=eye.sx/2
  eye.cy=eye.sy/2
  eye.x=eye.vx+eye.cx/eye.s
  eye.y=eye.vy+eye.cy/eye.s
  graph.setBackgroundColor(0,0,0)
end

function init_gui(Nick, Host)
  local o
  local cl={"R","t","V"}
  local x=25
  local objs={}
  for i,v in ipairs(cl) do
    if d_cl[v] then
      o=d_cl[v]:new(nil,x,eye.sy-25)
    end
    if u_cl[v] then
      o=u_cl[v]:new(nil,x,eye.sy-25)
    end
    o.hud=true
    objs[i]=o
    x=x+40
  end
  buydevs[1]=objs
  cl={"B"}
  x=25
  objs={}
  for i,v in ipairs(cl) do
    o=d_cl[v]:new(nil,x,eye.sy-25)
    o.hud=true
    objs[i]=o
    x=x+40
  end
  buydevs[2]=objs
  if Nick then
    nick = Nick
    init_st = 2
  end
  if Host then
    addr = Host
    init_st = 3
  end
end

local function init_enter()
  buf={}
  if init_st==1 then
    if readline.str:len()>15 or readline.str:len()<1 then
      readline:clr()
      return
    end
    if readline.str:match("[%a%d_%-]*")~=readline.str then
      readline:clr()
      return
    end
    nick=readline.str
    readline:clr()
    readline.sz=30
    init_st=2
    return
  end
  if init_st==2 then
    if readline.str:len()>30 or readline.str:len()<1 then
      readline:clr()
      return
    end
    if readline.str:match("[%a%d%.%-]*")~=readline.str then
      readline:clr()
      return
    end
    addr=readline.str
    readline:clr()
    init_st=3
    return
  end
end

function init_keypressed(key,ch)
  if console.input then
    console.input=console.keypressed(key,ch)
    return
  end
  if key=="escape" then
    love.event.push("q")
    return
  end
  if key=="return" then
    return init_enter()
  end
  if key=="`" or key=="f1" then
    console.input=true
    return
  end
  readline:key(key,ch)
end

function init_draw()
  graph.push()
  graph.scale(2)
  graph.setColor(255,255,255)
  if init_st==1 then
    readline:draw(50,eye.cy/2-20,"Nick: ")
    graph.print("Host: "..addr,50,eye.cy/2)
  end
  if init_st==2 then
    graph.print("Nick: "..nick,50,eye.cy/2-20)
    readline:draw(50,eye.cy/2,"Host: ")
  end
  if init_st>2 then
    graph.print("Nick: "..nick,50,eye.cy/2-20)
    graph.print("Host: "..addr,50,eye.cy/2)
    graph.print("connecting...",50,eye.cy/2+30)
  end
  if net_err then
    graph.print(net_err,50,eye.cy/2+50)
  end
  graph.pop()
  console.draw()
end

local cr_dt=0
function init_update(dt)
  cr_dt=cr_dt+dt
  if cr_dt>=0.5 then
    cr_dt=cr_dt-0.5
    readline.cr=not readline.cr
  end
  if init_st==3 then
    net_conn(addr,nick)
    init_st=9
  end
  if init_st>8 then
    if net_sync() then
      if ME then
        love.draw=main_draw
        love.update=main_update
        love.quit=main_quit
        love.keypressed=main_keypressed
        love.keyreleased=main_keyreleased
        love.mousepressed=main_mousepressed
        love.mousereleased=main_mousereleased
      end
    end
    if net_err then
      net_abort()
      init_st=1
    end
  end
  console.update(dt)
end
