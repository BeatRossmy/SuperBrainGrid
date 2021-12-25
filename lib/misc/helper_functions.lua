--[[index_to_coo = function (id)
  id = id-1
  x = id%8 + 1
  y = math.floor(id/8) + 1
  return {x=x,y=y}
end--]]


include("lib/misc/region")

new_area = function (_x,_y,_w,_h)
  a = {x=_x,y=_y,w=_w,h=_h}
  a.in_area = function (self,x,y)
    return (x>=self.x and y>=self.y and x<self.x+self.w and y<self.y+self.h)
  end
  a.relative = function (self,x,y,z)
    p = nil
    if self:in_area(x,y) then
      p = {}
      p.x = util.linlin(self.x,self.x+self.w,1,1+self.w,x)
      p.y = util.linlin(self.y,self.y+self.h,1,1+self.h,y)
      p.z = z
    end
    return p
  end
  return a
end

snap_length_to_array = function (length, snap_array)
  local snap_array_len = #snap_array
  if snap_array_len == 1 then
    length = snap_array[1]
  elseif length >= snap_array[snap_array_len] then
    length = snap_array[snap_array_len]
  else
    local delta
    local prev_delta = math.huge
    for s = 1, snap_array_len + 1 do
      if s > snap_array_len then
        length = length + prev_delta
        break
      end
      delta = snap_array[s] - length
      if delta == 0 then
        break
      elseif math.abs(delta) >= math.abs(prev_delta) then
        length = length + prev_delta
        break
      end
      prev_delta = delta
    end
  end
  return length
end

--[[index_to_pos = {
  {x=1,y=1},{x=2,y=1},{x=3,y=1},{x=4,y=1},{x=5,y=1},{x=6,y=1},{x=7,y=1},{x=8,y=1},
  {x=1,y=2},{x=2,y=2},{x=3,y=2},{x=4,y=2},{x=5,y=2},{x=6,y=2},{x=7,y=2},{x=8,y=2},
  {x=1,y=3},{x=2,y=3},{x=3,y=3},{x=4,y=3},{x=5,y=3},{x=6,y=3},{x=7,y=3},{x=8,y=3},
  {x=1,y=4},{x=2,y=4},{x=3,y=4},{x=4,y=4},{x=5,y=4},{x=6,y=4},{x=7,y=4},{x=8,y=4},
  {x=1,y=5},{x=2,y=5},{x=3,y=5},{x=4,y=5},{x=5,y=5},{x=6,y=5},{x=7,y=5},{x=8,y=5},
  {x=1,y=6},{x=2,y=6},{x=3,y=6},{x=4,y=6},{x=5,y=6},{x=6,y=6},{x=7,y=6},{x=8,y=6},
  {x=1,y=7},{x=2,y=7},{x=3,y=7},{x=4,y=7},{x=5,y=7},{x=6,y=7},{x=7,y=7},{x=8,y=7},
  {x=1,y=8},{x=2,y=8},{x=3,y=8},{x=4,y=8},{x=5,y=8},{x=6,y=8},{x=7,y=8},{x=8,y=8}
}--]]

v_range = function (buf,a,b,y,d_l,h_l)
  for x=a,b do
    local level = (x==a or x==b) and h_l or d_l
    buf:led_level_set(x,y,level)
  end
end

v_radio = function (buf,a,b,y,v,d_l,h_l)
  for x=a,b do
    local level = (x-(a-1)==v) and h_l or d_l
    buf:led_level_set(x,y,level)
  end
end

ui_matrix = function (buf,x,y,w,h,i_list,elements)
  if type(elements)=="nil" then elements = {} end
  for i=1,w*h,1 do
    local _x = x + (i-1)%w
    local _y = y + math.floor((i-1)/w)
    local _l = 1
    if i<=#i_list then _l = 3 end
    if tabutil.contains(elements,i_list[i]) then _l = 10 end
    buf:led_level_set(_x,_y,_l)
  end
end

ui_v_radio = function (buf,x,y,i_list,element)
  for i,e in ipairs(i_list) do
    local _x = x + (i-1)
    local _y = y 
    local _l = 2
    if e==element then _l = 10 end
    buf:led_level_set(_x,_y,_l)
  end
end

m_index = function (e,x,y,w,h)
  i = nil
  if e.x>=x and e.x<x+w and e.y>=y and e.y<y+h then
    x = 1+e.x-x
    y = e.y-y
    i = y*w+x
  end
  return i
end

i_matrix = function (i,x,y,w,h)
  m = nil
  if i<=w*h then
    m = {}
    m.x = x+((i-1)%w)
    m.y = y+math.floor((i-1)/w)
  end
  return m
end