-- vim:et

require "readline"

local readline=Readline:new(15)
local nick=""
local addr=""
local init_st=1
net_err=nil

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
  if key=="escape" then
    love.event.push("q")
    return
  end
  if key=="return" then
    return init_enter()
  end
  readline:key(key,ch)
end

function init_draw()
  graph.scale(2)
  graph.setColor(255,255,255)
  if init_st==1 then
    readline:draw(50,eye.cy/2-20,"Nick: ")
    graph.print("Host: "..addr,50,eye.cy/2)
    return
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
  if init_st>8 and net_err then
    graph.print(net_err,50,eye.cy/2+50)
  end
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
      else
        love.event.push("q")
      end
    end
  end
end
