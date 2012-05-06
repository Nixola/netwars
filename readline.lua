-- vim:et

class "Readline"

function Readline:initialize(size)
  self.buf={}
  self.len=0
  self.sz=size
  self.str=""
  self.i=1
  self.cr=true
end

function Readline:clr()
  self.buf={}
  self.len=0
  self.str=""
  self.i=1
end

function Readline:key(key,ch)
  if key=="left" then
    if self.i>1 then
      self.i=self.i-1
    end
    return
  end
  if key=="right" then
    if self.i<=self.len then
      self.i=self.i+1
    end
    return
  end
  if key=="home" then
    self.i=1
    return
  end
  if key=="end" then
    self.i=self.len+1
    return
  end
  if key=="backspace" then
    if self.i>1 then
      self.i=self.i-1
      table.remove(self.buf,self.i)
      self.len=self.len-1
      self.str=table.concat(self.buf)
    end
    return
  end
  if key=="delete" then
    if self.i<=self.len then
      table.remove(self.buf,self.i)
      self.len=self.len-1
      self.str=table.concat(self.buf)
    end
    return
  end
  if ch<32 or ch>127 then
    return
  end
  if self.len<self.sz then
    table.insert(self.buf,self.i,string.char(ch))
    self.len=self.len+1
    self.i=self.i+1
    self.str=table.concat(self.buf)
  end
end

function Readline:draw(x,y,prompt)
  local font=graph.getFont()
  local str=string.format("%s%s",prompt,self.str)
  local l=prompt:len()
  local wy=font:getHeight()
  local wx=font:getWidth(str:sub(1,self.i+l-1))
  graph.setColor(255,255,255)
  graph.print(str,x,y)
  graph.setLine(2,"rough")
  if self.cr then
    graph.line(x+wx,y,x+wx,y+wy)
  end
end
