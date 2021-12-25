new_track = function (_id,_keys)
  local track = {
    id = _id,
    keys = _keys,
    engine_type = 1, -- nil
    engine = nil,
    output = Poly_Fork:new(), --"engine",1,"poly"
    visible = false,
    
    -- handle_keaboard = function (self) end,
    
    reset_engine = function (self)
      self:set_engine(self.engine_type,nil)
    end,
    
    set_engine = function (self, engine_type, engine_state)
      if self.engine then self.engine:destroy() end
      self.engine = nil
      self.engine_type = engine_type
      self.engine = new_engine[engine_type](engine_state, self)
      
      -- self.engine:init(self)
      
      if self.visible then self.keys.target = self.engine end
      self.engine.keys = self.keys
    end,
    
    set_visible = function (self)
      if not self.visible then
        self.keys.target = self.engine
      end
      self.visible = true
    end,
    
    set_unvisible = function (self)
      if self.visible then
        self.keys.target = nil
      end
      self.visible = false
    end,
    
    handle_settings = function (self, e)
      if (e.type=="press" or e.type=="double") then
        -- 1st row -> engine: ...
        local i = m_index(e,1,1,2,4)
        if i and i<=#engines then
          self:set_engine(i,nil)
          BRAIN:set_overlay("engine",engines[i])
          return
        end
          
        -- 2nd row -> target: internal, midi & ports: 1-4
        --i = m_index(e,9,1,1,#Poly_Fork.targets)
        i = m_index(e,8,1,2,4)
        if i and i<=#Poly_Fork.targets then
          self.output:set_target(i)
          BRAIN:set_overlay("target",self.output.target.type)
          return
        end
        
        -- port
        i = m_index(e,10,1,1,4)
        if i and i<=#midi_slots then
          self.output:set_port(i)
          BRAIN:set_overlay("slot",midi_slots[i].name)
          return
        end
        
        -- 3rd row -> mode: poly, fork(=mono)
        i = m_index(e,12,1,1,2)
        if i and self.output.target.mode then
          self.output:set_mode(i)
          BRAIN:set_overlay("midi routing",self.output.target.mode)
          return
        end
        
        -- 4+5 row -> channels
        i = m_index(e,13,1,4,4)
        if i then
          self.output:add_channels({i})
          BRAIN:set_overlay("channel",i)
          return
        end
      end
    end,
    
    show_settings = function (self, buf)
      -- ENGINES
      ui_matrix(buf,1,1,2,4,engines,{engines[self.engine_type]})
      -- TRAGET
      ui_matrix(buf,8,1,2,4,Poly_Fork.targets,{self.output.target.type})
      -- MIDI DEV
      local list = {}
      if self.output.target.port then
        
        for i=1,#midi_slots do table.insert(list,i) end
      end
      ui_matrix(buf,10,1,1,4,list,{self.output.target.port})
      -- POLY MODE
      local list = {}
      if self.output.target.mode then list = Poly_Fork.modes end
      ui_matrix(buf,12,1,1,2,list,{self.output.target.mode})
      -- CHANNELS
      local list = {1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16}
      if self.output.target.type=="crow" then list = {1,2}
      elseif not self.output.target.channels then list = {} end
      ui_matrix(buf,13,1,4,4,list,self.output.target.channels)
    end,
    
    rec = function(self) end,
    
    play = function(self)
      if self.engine then self.engine:play() end
    end,
    
    stop = function(self) 
      if self.engine then self.engine:stop() end
      -- self:save()
    end,
    
    save = function (self)
      e = self.engine and self.engine:get() or {}
      s = {id=self.id, engine=e, output=self.output:get()}
      tabutil.save(s, _path.data.."SUPER_BRAIN/"..self.id.."_track_state.txt")
    end,
    
    redraw = function (self)
      screen.level(15)
      screen.font_size(32)
      screen.move(64,48)
      screen.text_center(engine_icons[self.engine_type])
    end,
    
    get_state_for_preset = function (self)
      return {id=self.id, engine=self.engine, output=self.output:get()}
    end,
    
    load_preset = function (self, preset)
      local engine_state = preset["engine"]
      local engine_type = preset["engine"]["name"]
      if engine_type then self:set_engine(tabutil.key(engines,engine_type),engine_state) end
      local output_config = preset["output"]
      self.output:init(output_config)
    end
  }
  
  track:reset_engine()
  track.output:init()
  
  return track
end