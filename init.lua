-- vim:et

local nick=""
local addr=""
local str=""
local init_st=1

local function init_enter()
  if init_st==1 then
    if str:len()>15 or str:len()<1 then
      str=""
      return
    end
    if str:match("[%a%d]*")~=str then
      str=""
      return
    end
    nick=str
    str=""
    init_st=2
    return
  end
  if init_st==2 then
    if str:len()>30 or str:len()<1 then
      str=""
      return
    end
    if str:match("[%a%d.]*")~=str then
      str=""
      return
    end
    addr=str
    str=""
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
  if key=="backspace" then
    str=str:sub(1,-2)
    return
  end
  if ch<32 or ch>127 then
    return
  end
  if str:len()<30 then
    str=str..string.char(ch)
  end
end

function init_draw()
  graph.setColor(255,255,255)
  graph.setPoint(2,"rough")
  graph.scale(2)
  graph.print("Nick: "..nick,50,eye.cy/2-20)
  graph.print("Host: "..addr,50,eye.cy/2)
  if init_st>2 then
    graph.print("connecting...",50,eye.cy/2+30)
  end
end

function init_update(dt)
  if init_st==1 then
    nick=str
  end
  if init_st==2 then
    addr=str
  end
  if init_st==3 then
    net_conn(addr,nick)
    init_st=9
  end
end