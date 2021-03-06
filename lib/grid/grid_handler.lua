local event_phase = {"press","release","double","release"}
local HOLD_TIME = 0.3
local DOUBLE_GAP = 0.15
local CLICK_TIME = 0.2

GRID_EVENT_mt = {__eq = function (e1, e2) return (e1.x==e2.x and e1.y==e2.y) end}
GRID_EVENT = function (_x,_y,_z,_t)
  event = {x=_x,y=_y,z=_z,time=_t,type=_z==1 and "press" or "release",clock_id=nil,phase=0}
  
  event.copy = function (self) return {x=self.x,y=self.y,z=self.z,type=self.type,time=self.time} end
  
  event.next_phase = function (self, last)
    self.phase = self.z~=0 and 1 or 2
    self.type = event_phase[self.phase]
    
    if last then
      dt = self.time-last.time
      self.clock_id = last.clock_id
      self.phase = util.wrap(last.phase+1,1,4)
      if dt>DOUBLE_GAP and self.phase==3 then self.phase = 1 end
      self.type = event_phase[self.phase]
      if self.phase%2==0 and dt<CLICK_TIME then self.type = self.phase == 2 and "click" or "double_click" end
    end
  end
  
  --[[event.next_phase = function (self, last)
    self.phase = self.z~=0 and 1 or 2
    self.type = self.z~=0 and "press" or "release"
    if last then
      dt = self.time-last.time
      self.phase = last.phase==4 and 1 or last.phase+1
      if self.phase==3 and dt>0.4 then self.phase = 1 end
      self.type = event_phase[self.phase]
      if (self.phase==2 or self.phase==4) and dt<0.25 then self.type = self.phase == 2 and "click" or "double_click" end
    end
  end--]]
  
  setmetatable(event, GRID_EVENT_mt)
  
  return event
end

Grid_Handler = {
  new = function () 
    return {
      event_stack = {},
      
      key = function (self,x,y,z) 
        e = GRID_EVENT(x,y,z,util.time())
        last_e = tabutil.get(self.event_stack,e)
        if last_e then tabutil.remove(self.event_stack,last_e) end
        
        e:next_phase(last_e)
          
        if e.phase == 1 or e.phase == 3 then
          _e = e:copy()
          _e.type = e.phase == 1 and "hold" or "double_hold"
          
          if e.clock_id then
            clock.cancel(e.clock_id)
            e.clock_id = nil
          end
          
          e.clock_id = clock.run(self.wait_for,self,_e,HOLD_TIME)
        elseif e.phase == 2 or e.phase == 4 then
          if last_e then
            clock.cancel(last_e.clock_id)
            last_e.clock_id = nil
          end
        end
        
        --if last_e then tabutil.remove(self.event_stack,last_e) end
        table.insert(self.event_stack,e)
        
        if e.type=="click" then
          _e = e:copy()
          e.clock_id = clock.run(self.wait_for,self,_e,DOUBLE_GAP*1.001)
        else
          print(e.type,e.clock_id,last_e and last_e.clock_id or nil)
          self.grid_event(e:copy())
        end
      end,
      
      --[[key = function (self,x,y,z) 
        e = GRID_EVENT(x,y,z,util.time())
        last_e = tabutil.get(self.event_stack,e)
        e:next_phase(last_e)
          
        if e.phase == 1 or e.phase == 3 then
          _e = e:copy()
          _e.type = e.phase == 1 and "hold" or "double_hold"
          e.clock_id = clock.run(self.wait_for,self,_e,HOLD_TIME)
        elseif e.phase == 2 or e.phase == 4 then
          if last_e then clock.cancel(last_e.clock_id) end
        end
        
        if last_e then tabutil.remove(self.event_stack,last_e) end
        table.insert(self.event_stack,e)
        self.grid_event(e:copy())
      end,--]]
      
      wait_for = function (self, e, t)
        clock.sleep(t)
        print(e.type,e.clock_id,last_e and last_e.clock_id or nil)
        self.grid_event(e)
      end,
      
      grid_event = function (e) end
    }
  end
}

return Grid_Handler