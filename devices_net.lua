-- vim:et

function Device:net_buy(x,y)
  net_send("B:%s:%.1f:%.1f\n",self.cl,x,y)
end

function Device:net_delete()
  net_send("D:%d\n",self.idx)
end

function Device:net_move(x,y)
  x,y=self:calc_xy(x,y)
  net_send("M:%d:%.1f:%1.f\n",self.idx,x,y)
end

function Device:net_connect(dev)
  if #self.links>=self.maxlinks then
    return
  end
  if vec.len(self.x,self.y,dev.x,dev.y)>250 then
    return
  end
  net_send("L:%d:%d\n",self.idx,dev.idx)
end

function Device:net_switch()
  if self.online then
    net_send("S:%d:0\n",self.idx)
  else
    net_send("S:%d:1\n",self.idx)
  end
end
