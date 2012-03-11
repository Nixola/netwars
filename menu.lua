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
  y=y-(#self.items*8)
  graph.setLine(1,"rough")
  for k,v in pairs(self.items) do
    l=#v.str*9
    if msx>x and msx<x+l and msy>y and msy<y+16 then
      graph.setColor(219,159,223)
      graph.rectangle("fill",x,y,#v.str*9,16)
      graph.setColor(255,255,255)
      graph.rectangle("line",x,y,#v.str*9,16)
      graph.setColor(0,0,0)
      graph.print(v.str,x+3,y+1)
    else
      graph.setColor(0,0,0)
      graph.rectangle("fill",x,y,#v.str*9,16)
      graph.setColor(255,255,255)
      graph.rectangle("line",x,y,#v.str*9,16)
      graph.setColor(255,255,255)
      graph.print(v.str,x+3,y+1)
    end
    y=y+16
  end
end

function Menu:switch(fs,ts)
  for k,v in pairs(self.items) do
    if v.str==fs then
      v.str=ts
      return
    end
  end
end

function Menu:click()
  local x,y=(self.obj.x+eye.vx)*eye.s+eye.cx,(self.obj.y+eye.vy)*eye.s+eye.cy
  x=x+(self.obj.r+8)*eye.s
  y=y-(#self.items*8)
  for k,v in pairs(self.items) do
    l=#v.str*8+6
    if msx>x and msx<x+l and msy>y and msy<y+16 then
      if v.str=="Delete" then
        v.str="DELETE"
        return self
      end
      v.func(self.obj)
      break
    end
    y=y+16
  end
  for k,v in pairs(self.items) do
    if v.str=="DELETE" then
      v.str="Delete"
      break
    end
  end
  return nil
end
