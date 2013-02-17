-- vim:et

local nodes={}
local map={}

local R_mfl=5
local R_mbl=5
local G_mfl=3
local G_mbl=2
local T_mbl=2

local function get_cell(x,y,d,c)
  local v={{0,-4},{3,-2},{3,2},{0,4},{-3,2},{-3,-2}}
  if d and d~=0 then
    c=c or 1
    x=x+v[d][1]*c
    y=y+v[d][2]*c
    local k=string.format("%d,%d",x,y)
    return k,x,y
  end
  local k=string.format("%d,%d",x,y)
  return k,x,y
end

local function rnd_cell(sz,off)
  local x=math.random(-sz,sz)
  local y=math.random(-sz,sz)
  if off then
    x=x<0 and x-off or x+off
    y=y<0 and y-off or y+off
  end
  if math.abs(x)%2==1 then
    if y==0 then
      y=math.random()>0.5 and 1 or -1
    end
    y=y*2
  else
    y=y*4
  end
  x=x*3
  local k=string.format("%d,%d",x,y)
  return k,x,y
end

local function link_node(n1,n2)
  if n1.flc>=R_mfl or n2.blc>=R_mbl then
    return
  end
  if not n1.l[n2] and not n2.l[n1] then
    n1.l[n2]=n2
    n1.flc=n1.flc+1
    n2.blc=n2.blc+1
  end
end

local function R_node(n)
  local x,y=n.x*60,n.y*60
  n.x=x+math.random(-20,20)
  n.y=y+math.random(-20,20)
  n.ec=math.random(3)
  return {n}
end

local function T_node(n)
  local x,y=n.x*60,n.y*60
  n.x=x+math.random(-20,20)
  n.y=y+math.random(-20,20)
  n.ec=math.random(3)
  return {n}
end

local function G_node(n)
  local res={}
  local t
  local x,y=n.x*60,n.y*60
  n.x=x
  n.y=y
  n.tp="R"
  n.ec=math.random(2)+1
  res[n]=n
  -- 3x Generators
  t={tp="G",l={}}
  t.x=x
  t.y=y-4*20
  t.pwr=math.random(3,10)
  t.l[n]=n
  res[t]=t
  t={tp="G",l={}}
  t.x=x+3*20
  t.y=y+2*20
  t.pwr=math.random(3,10)
  t.l[n]=n
  res[t]=t
  t={tp="G",l={}}
  t.x=x-3*20
  t.y=y+2*20
  t.pwr=math.random(3,10)
  t.l[n]=n
  res[t]=t
  return res
end

local function S1_node(n)
  local res={}
  local t
  local x,y=n.x*60,n.y*60
  -- 1x Generator
  t={tp="G",l={}}
  t.x=x+math.random(-20,20)
  t.y=y+math.random(-20,20)
  t.pwr=5
  res[t]=t
  return res
end

local function S3_node(n)
  local res={}
  local t
  local x,y=n.x*60,n.y*60
  -- 3x Generators
  t={tp="G",l={}}
  t.x=x
  t.y=y-4*20
  t.pwr=3
  res[t]=t
  t={tp="G",l={}}
  t.x=x+3*20
  t.y=y+2*20
  t.pwr=3
  res[t]=t
  t={tp="G",l={}}
  t.x=x-3*20
  t.y=y+2*20
  t.pwr=3
  res[t]=t
  return res
end

local function gen_map()
  local tmp={}
  local tmp2
  local t,x,y,k,d,r,tp
  local tx,ty
  k,x,y=get_cell(0,0)
  t={x=x,y=y,tp="G",l={},flc=0,blc=3}
  nodes[t]=t
  tmp[t]=t
  map[k]=t
  for i=1,6 do
    k,tx,ty=get_cell(0,0,i,8)
    for d=2,6,2 do
      k,x,y=get_cell(tx,ty,d)
      if not map[k] then
        t={x=x,y=y,tp="S3",l={}}
        nodes[t]=t
        map[k]=t
      end
    end
  end
  -- generate R+G
  for i=1,20 do
    tmp2={}
    r=i<3 and math.random(3)+1 or math.random(3)
    for _=1,r do
      for _,n in pairs(tmp) do
        if n.tp=="G" then
          d=math.random(3)*2
        else
          d=math.random(6)
        end
        k,x,y=get_cell(n.x,n.y,d)
        t=map[k]
        if t then
          if t.tp=="R" then
            link_node(n,t)
          end
        else
          if n.tp=="R" and math.random()>0.7 and d%2==1 then
            t={x=x,y=y,tp="G",l={},flc=0,blc=3}
          else
            t={x=x,y=y,tp="R",l={},flc=0,blc=0}
          end
          nodes[t]=t
          tmp2[t]=t
          map[k]=t
          if n.tp=="G" and d%2==0 and t.tp=="R" then
            link_node(n,t)
          end
          if n.tp=="R" and t.tp=="G" and d%2==1 then
            link_node(t,n)
          end
          if n.tp=="R" and t.tp=="R" then
            link_node(n,t)
          end
        end
      end
    end
    tmp=tmp2
  end
  -- convert leaf R to T
  for _,n in pairs(nodes) do
    if n.tp=="R" and n.flc<1 then
      n.tp="T"
    end
  end
  -- fix nodes
  for _,n in pairs(nodes) do
    if n.tp=="G" then
      for d=2,6,2 do
        k=get_cell(n.x,n.y,d)
        t=map[k]
        if t and (t.tp=="R" or t.tp=="T") and not t.l[n] and not n.l[t] then
          link_node(n,t)
        end
      end
    end
    if n.tp=="R" and n.flc<1 then
      for d=1,6 do
        k=get_cell(n.x,n.y,d)
        t=map[k]
        if t and (t.tp=="R" or t.tp=="T") and not t.l[n] and not n.l[t] then
          link_node(n,t)
        end
      end
    end
  end
end

local function fix_nodes()
  local res={}
  local t
  for _,n in pairs(nodes) do
    if n.tp=="G" then
      t=G_node(n)
    elseif n.tp=="R" then
      t=R_node(n)
    elseif n.tp=="T" then
      t=T_node(n)
    elseif n.tp=="S1" then
      t=S1_node(n)
    elseif n.tp=="S3" then
      t=S3_node(n)
    end
    for _,o in pairs(t) do
      res[o]=o
    end
  end
  return res
end

arg={...}
math.randomseed(tonumber(arg[1]))
gen_map()
nodes=fix_nodes()

return function()
  for _,n in pairs(nodes) do
    if n.tp=="G" then
      n.obj=add_G(n.x,n.y,n.pwr)
    elseif n.tp=="R" then
      n.obj=add_R(n.x,n.y,n.ec)
    elseif n.tp=="T" then
      n.obj=add_T(n.x,n.y,n.ec)
    end
  end
  for _,n in pairs(nodes) do
    for _,t in pairs(n.l) do
      if n.obj and t.obj then
        n.obj:link(t.obj)
      end
    end
  end
end
