ISO_KEYS = {
  area = new_area(4,5,10,4),
  visible = true,
  
  rootnote = 60,
  offset = 0,
  interval = 5,
  device = nil,
  channel = 9,
  held_notes = {},
  target = nil,
  
  external_notes = nil,
  
  get_held_notes = function (self)
    return self.held_notes
  end,
  
  set_device = function (self, d)
    self.device = d
  end,
  
  transpose = function (self, d)
    if d == 1 and self.rootnote + self.offset + 5 + 22 < 127 then self.offset = self.offset + 5 end
    if d == -1 and self.rootnote + self.offset +  -5 >= 0 then self.offset = self.offset - 5 end
  
    for _,n in pairs(self.held_notes) do
      if self.target then self.target.output:note_off(n,0) end
    end
    self.held_notes = {}
  end,
  
  key = function (self,x,y,z)
    local p = self.area:relative(x,y)
    x = p.x
    y = p.y
    local pitch = self:get_pitch(x,y)
    -- 
    local velocity = math.floor(z*100)
    self:note(pitch,velocity)
    --[[local contains_pitch = tabutil.contains(self.held_notes,pitch)
    if z>0 and not contains_pitch then
      table.insert(self.held_notes,pitch)
      if self.target then self.target:note_on(pitch,z) end
    elseif z == 0 and contains_pitch then
      tabutil.remove(self.held_notes,pitch)
      if self.target then self.target:note_off(pitch,z) end
    end--]]
  end,
  
  note = function (self,pitch,velocity)
    velocity = velocity/100
    local contains_pitch = tabutil.contains(self.held_notes,pitch)
    if velocity>0 and not contains_pitch then
      table.insert(self.held_notes,pitch)
      if self.target then self.target:note_on(pitch,velocity) end
    elseif velocity == 0 and contains_pitch then
      tabutil.remove(self.held_notes,pitch)
      if self.target then self.target:note_off(pitch,velocity) end
    end
  end,
  
  redraw = function (self, buf)
    list = self.external_notes
    
    for i=1,40 do
      local x = (i-1)%10
      local y = math.floor((i-1)/10)
      local z = 2
      
      local pitch = self.rootnote + self.offset + x + (3-y)*self.interval
      if tabutil.contains(self.held_notes,pitch) or (list and tabutil.contains(list, pitch)) then z = 15
      elseif (pitch-self.rootnote)%12 == 0 then z = 10
      elseif (pitch-self.rootnote)%12 == 9 then z = 5 end
        
      buf:led_level_set(4+x,5+y,z)
    end
    
    -- TRANSPOSE BUTTONS
    buf:led_level_set(14,5,math.floor(util.linlin(-60,40,1,15,self.offset)))
    buf:led_level_set(14,6,math.floor(util.linlin(-60,40,15,1,self.offset)))
  end,
  
  get_pitch_index = function (self, index)
    coo = index_to_coo(index)
    pitch = self.rootnote + self.offset + (coo.x-1) + (8-coo.y)*self.interval
    return pitch
  end,
  get_pitch = function (self,x,y)
    pitch = self.rootnote + self.offset + (x-1) + (4-y)*self.interval
    return pitch
  end
}

return ISO_KEYS