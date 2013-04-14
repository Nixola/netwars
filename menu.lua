-- vim:et

class "Menu"

function Menu:initialize(o)
  self.items={}
  self.obj=o
end

function Menu:add(s,v)
  if type(v)=="table" then
    self.items[#self.items+1]={str=s,menu=v}
    v.parent=self
  else
    self.items[#self.items+1]={str=s,func=v}
  end
end

function Menu:draw()
  local x,y=(self.obj.x+eye.vx)*eye.s+eye.cx,(self.obj.y+eye.vy)*eye.s+eye.cy
  x=x+(self.obj.r+8)*eye.s
  y=y-(#self.items*9)
  graph.setLine(1,"rough")
  local ml=0
  for _,v in pairs(self.items) do
    local l=v.str:len()
    if ml<l then
      ml=l
    end
  end
  ml=ml*10
  for _,v in pairs(self.items) do
    if msx>x and msx<x+ml-2 and msy>y and msy<y+17 then
      graph.setColor(219,159,223)
      graph.rectangle("fill",x,y,ml-1,18)
      graph.setColor(255,255,255)
      graph.rectangle("line",x,y,ml,19)
      graph.setColor(0,0,0)
      graph.print(v.str,x+3,y+2)
    else
      graph.setColor(0,0,0)
      graph.rectangle("fill",x,y,ml-1,18)
      graph.setColor(255,255,255)
      graph.rectangle("line",x,y,ml,19)
      graph.setColor(255,255,255)
      graph.print(v.str,x+3,y+2)
    end
    y=y+19
  end
end

function Menu:switch(fs,ts)
  for _,v in pairs(self.items) do
    if v.str==fs then
      v.str=ts
      return
    end
  end
end

function Menu:cleanup()
  for k,v in pairs(self.items) do
    if v.str=="UNLINK" then
      v.str="Unlink"
      break
    end
  end
end

function Menu:click(mx,my)
  local x,y=(self.obj.x+eye.vx)*eye.s+eye.cx,(self.obj.y+eye.vy)*eye.s+eye.cy
  x=x+(self.obj.r+8)*eye.s
  y=y-(#self.items*9)
  local ml=0
  for _,v in pairs(self.items) do
    local l=v.str:len()
    if ml<l then
      ml=l
    end
  end
  ml=ml*10
  for _,v in pairs(self.items) do
    if mx>x and mx<x+ml-2 and my>y and my<y+17 then
      if v.str=="Unlink" then
        v.str="UNLINK"
        return self
      end
      v.func(self.obj)
      break
    end
    y=y+19
  end
  self:cleanup()
  return nil
end
