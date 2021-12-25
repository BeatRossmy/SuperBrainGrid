NOTE_mt = {__eq = function (e1, e2) return (e1.note==e2.note) end}
NOTE = function (_note,_vel,_ch)
  note = {note=_note,vel=_vel,ch=_ch}
  setmetatable(note, NOTE_mt)
  return note
end

CH_mt = {__eq = function (e1, e2) return (e1.ch==e2.ch) end,
         __lt = function (e1, e2) return (e1.ch<e2.ch) end,
         __le = function (e1, e2) return (e1.ch<=e2.ch) end}
CH = function (_ch)
  ch = {ch=_ch,used=util.time()}
  setmetatable(ch, CH_mt)
  return ch
end

local Targets = {
  ["engine"] = function () return {
    type="engine",
    note_on = function (self,note,vel)
      Poly_Fork.engine_on(note,vel)  
    end,
    note_off = function (self,note,vel)
      Poly_Fork.engine_off(note,vel)  
    end
  } end,
  ["midi"] = function () return {
    type="midi",
    port=1, -- [1,4]
    mode="poly",
    channels={1},
    note_on = function (self,note,vel,ch)
      vel = math.floor(util.linlin(0,1,0,100,vel))
      midi_slots[self.port].device:note_on(note,vel,ch)
    end,
    note_off = function (self,note,vel,ch)
      vel = math.floor(util.linlin(0,1,0,100,vel))
      midi_slots[self.port].device:note_off(note,vel,ch)
    end
  } end,
  ["crow"] = function () return {
    type="crow",
    mode="poly",
    channels={1},
    init = function ()
      for ch=0,2,2 do
        -- CV
        crow.output[ch+1].slew = 0
        crow.output[ch+1].scale({}, 12, 1.0) -- chromatic scale
        -- GATE
        crow.output[ch+2].slew = 0.001 -- prevent wrong pitch tracking ~ gate delay
      end
    end,
    note_on = function (self,note,vel,ch)
      ch = (ch-1)*2
      crow.output[ch+1].volts = util.linlin(0,120,-5,5,note)
      crow.output[ch+2].volts = 5
    end,
    note_off = function (self,note,vel,ch)
      ch = (ch-1)*2
      crow.output[ch+2].volts = 0
    end
  } end,
  ["disting"] = function () return {
    type="disting",
    init = function ()
      crow.ii.raw(0x41,'\x57')
    end,
    note_on = function (self,note,vel,ch)
      local volt = util.linlin(0,120,-4,6,note)*1638.4
      local msb = (math.floor(volt)>>8)&0xFF
      local lsb = (math.floor(volt))&0xFF
      
      print(note,volt,vel)
      vel = string.char(math.floor(util.clamp(vel*100,1,127)))
      note = string.char(util.clamp(note,0,120))
      -- PITCH
      crow.ii.raw(0x41,'\x54'..note..string.char(msb)..string.char(lsb))
      -- VELOCITY
      crow.ii.raw(0x41,'\x55'..note..vel..'\x00')
    end,
    note_off = function (self,note,vel,ch)
      note = string.char(util.clamp(note,0,120))
      crow.ii.raw(0x41,'\x56'..note)
    end
  } end,
  ["disting_midi"] = function () return {
    type="disting_midi",
    mode="poly",
    channels={1},
    init = function ()
      -- all notes off : 123
      crow.ii.disting.midi(0xB0,123)
    end,
    note_on = function (self,note,vel,ch)
      vel = math.floor(util.clamp(vel*100,1,127))
      crow.ii.disting.midi(0x90+(ch-1),note,vel)
    end,
    note_off = function (self,note,vel,ch)
      crow.ii.disting.midi(0x80+(ch-1),note,vel)
    end
  } end
}

if not crow_connected then
  Targets["crow"] = nil
  Targets["disting"] = nil
  Targets["disting_midi"] = nil
end

Poly_Fork = {
  engine_on = function(pitch,vel) end,
  engine_off = function(pitch,vel) end,
  targets = {"engine","midi","crow","disting","disting_midi"},
  modes = {"poly","fork"},
  
  new = function (self)
    pf = {
      target = Targets["engine"](),
      channels = {},
      active_notes = {},
      
      get = function (self)
        local ch = {}
        -- for _,c in pairs(self.channels) do table.insert(ch,c.ch) end
        -- return{port=self.port,channels=ch,mode=self.mode,target=self.target}
      end,
      
      init = function (self, out_config)
        -- self.engine_on = Poly_Fork.engine_on
        -- self.engine_off = Poly_Fork.engine_off
        
        --[[if out_config then
          self.port = out_config["port"]
          self.device = midi_slots[self.port].device
          
          self.target = out_config["target"]
          self.mode = out_config["mode"]
          
          local ch = out_config["channels"]
          self.channels = {}
          self:add_channels(ch)
        end--]]
      end,
      
      set_target = function (self, t)
        self:kill_all_notes()
        t = Poly_Fork.targets[t]
        if t==self.target.type then return end
        self.target = Targets[t]()
        if self.target.init then self.target.init() end
        
        self.channels = {}
        if self.target.channels then
          for _,c in pairs(self.target.channels) do
            tabutil.add_or_remove(self.channels,CH(c))
          end
        end
      end,
      
      target_key = function (self)
        return tabutil.key(Poly_Fork.targets,self.target.type)
      end,
      
      set_port = function (self, p)
        self:kill_all_notes()
        if self.target.port then self.target.port = p end
      end,
      
      set_mode = function (self, m)
        self:kill_all_notes()
        if self.target.mode then
          self.target.mode = Poly_Fork.modes[m]
          if self.target.mode=="poly" then
            table.sort(self.target.channels)
            local n_ch = self.target.channels[1]
            self.target.channels = {n_ch}
            self.channels = {CH(n_ch)}
          end
        end
      end,
      
      mode_key = function (self)
        return self.target.mode and tabutil.key(Poly_Fork.modes,self.target.mode) or nil
      end,
      
      kill_all_notes = function (self)
        for _,note in pairs(self.active_notes) do
          self:note_off(note.note,note.vel)
        end
      end,
      
      clear_channels = function (self)
        if self.target.channels then
          self.target.channels = {}
          self.channels = {}
        end
      end,
      
      add_channels = function (self, ch)
        if self.target.mode=="poly" then
          if #ch>0 then
            self:clear_channels()
            if self.target.type=="crow" then ch = util.clamp(ch[1],1,2)
            --elseif self.target.type=="midi" then ch = util.clamp(ch[1],1,16) end
            else ch = util.clamp(ch[1],1,16) end
            self.target.channels[1] = ch
            self.channels[1] = CH(ch)
          end
          return
        end
        for _,c in pairs(ch) do
          if #self.target.channels>1 or tabutil.contains(self.target.channels,c)==false then
            if self.target.type=="crow" then c = util.clamp(c,1,2)
            elseif self.target.type=="midi" then ch = util.clamp(ch[1],1,16) end
            tabutil.add_or_remove(self.target.channels,c)
            tabutil.add_or_remove(self.channels,CH(c))
          end
        end
      end,
      
      get_notes = function (self)
        local notes = {}
          for _,n in pairs(self.active_notes) do table.insert(notes,n.note) end
        return notes
      end,
      
      note = function (self,note,vel,length,delay)
        clock.run(function (s,n,v,l,d)
          if d then clock.sleep(d) end
          s:note_on(n,v)
          clock.sleep(l)
          s:note_off(n,0)
        end,self,note,vel,length,delay)
      end,
      
      notes = function (self,notes,delay)
        if not notes then return end
        for _,n in pairs(notes) do
          self:note(n.note,n.vel,n.length,delay)
        end
      end,
      
      next_channel = function (self)
        local ch = 1
        if self.target.mode=="poly" and #self.target.channels>0 then
          ch = self.channels[1].ch
        elseif self.target.mode=="fork" then
          if #self.active_notes==#self.channels then -- stop one note if all channels are full
            n = self.active_notes[1]
            self:note_off(n.note,0,n.ch)
          end
          table.sort(self.channels,function(a,b) return a.used>b.used end)
          ch = self.channels[#self.channels].ch
          self.channels[#self.channels].used = 100000000000 + util.time()
        end
        return ch
      end,
      
      note_on = function (self,note,vel)
        local ch = self:next_channel()
        self.target:note_on(note,vel,ch)
        table.insert(self.active_notes,NOTE(note,vel,ch))
      end,
      
      note_off = function (self,note,vel)
        local n = tabutil.get(self.active_notes,NOTE(note,0,0))
        if n then
          if self.target.mode=="fork" then
            for _,c in pairs(self.channels) do if n.ch==c.ch then c.used = util.time() break end end  
          end
          self.target:note_off(note,vel,n.ch)
          tabutil.remove(self.active_notes,n)
        end
      end
    }
    
    return pf
  end
}

if not crow_connected then
  tabutil.remove(Poly_Fork.targets,"crow")
  tabutil.remove(Poly_Fork.targets,"disting")
  --tabutil.remove(Poly_Fork.targets,"disting_midi") -- problem: removes "midi"
end