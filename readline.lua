-- vim:et

class "Readline"

function Readline:initialize(size)
  self.buf={}
  self.len=0
  self.sz=size
  self.str=""
  self.i=1
  self.cr=true
  self.hist={}
  self.old=nil
  self.hi=0
end

function Readline:clr()
  self.buf={}
  self.len=0
  self.str=""
  self.i=1
  self.old=nil
  self.hi=0
end

function Readline:done()
  self.hist[#self.hist+1]=self.buf
  self:clr()
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
  if key=="up" then
    if #self.hist<1 then
      return
    end
    if self.hi>1 then
      self.hi=self.hi-1
    end
    if self.hi==0 then
      self.old=self.buf
      self.hi=#self.hist
    end
    self.buf=icopy(self.hist[self.hi])
    self.len=#self.buf
    self.i=self.len+1
    self.str=table.concat(self.buf)
    return
  end
  if key=="down" then
    if #self.hist<1 then
      return
    end
    if self.hi==0 then
      return
    end
    if self.hi<#self.hist then
      self.hi=self.hi+1
      self.buf=icopy(self.hist[self.hi])
      self.len=#self.buf
      self.i=self.len+1
      self.str=table.concat(self.buf)
      return
    end
    if self.old then
      self.hi=0
      self.buf=self.old
      self.len=#self.buf
      self.i=self.len+1
      self.str=table.concat(self.buf)
    end
    return
  end
  if not ch or ch==96 or ch<32 or ch>125 then
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
