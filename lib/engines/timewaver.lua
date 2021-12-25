local PRE_REC = 2

TimeWaver = {
  name = "time~waver",
  icon = "~",
  
  loop_quantization = {4,8,16,32,64,128}, -- 1bar, 2bar, 4bar, ...
  
  Wave = function (o,conf)
    return {
      steps = conf and conf["steps"] or {},
      playing = conf and conf["playing"] or false,
      recording = false,
      
      start_beat = conf and conf["start_beat"] or 0,
      length = conf and conf["length"] or nil,
      step_quant = conf and conf["step_quant"] or 1/4, --beat -> 1/16 bar
      
      loop_region = Region(),
      
      phase = 0,
      clock_id = nil,
      out = o,
      
      loop_quant = conf and conf["loop_quant"] or 1,
      mute = false,
      
      toggle_loop = function (self, i)
        self.loop_region:set(i)
      end,
      
      destroy = function (self)
        if self.clock_id then clock.cancel(self.clock_id) end
        self = nil
      end,
      
      calculate_next_beat = function (interval)
        return util.round_up(clock.get_beats(),interval)
      end,
      
      quant = function (self,step,threshold)
        local s = math.fmod(step,self.step_quant)
        s = util.linlin(0,self.step_quant,0,1,s)
        step = util.round_up(step,self.step_quant)
        return s>threshold and step or step-self.step_quant
      end,
      
      clear_segment = function (self, s)
        local a = util.round((s-1)/16 * self.length, self.step_quant)
        local b = util.round(s/16 * self.length,self.step_quant)
        for i=a,b,self.step_quant do
          if self.steps[i] then self.steps[i] = nil end
        end
      end,
      
      rec_note = function(self, note)
        local step = note.beat-self.start_beat
        step = self:quant(step,0.666)
        
        if self.clock_id then
          -- step = math.fmod(step,self.length)
          local phase = self:calc_phase(note.beat)
          print("phase",phase)
          step = phase*self.length
          step = self:quant(step,0.666)
        end
        
        print("rec")
        if not self.recording or step<0 then return end
        
        if self.steps[step]==nil then self.steps[step] = {} end
        table.insert(self.steps[step],{note=note.note,vel=note.vel,length=note.length})
        print(#self.steps)
      end,
      
      rec = function (self)
        if self.recording then return end
        self.recording = true
        self.start_beat = self.length and self.start_beat or self.calculate_next_beat(PRE_REC)
      end,
      
      stop_rec = function (self)
        if not self.recording then return end
        -- INITIAL LOOP
        if not self.length then
          local q = self.loop_quant
          self.length = util.round(clock.get_beats() - self.start_beat, q and q or self.step_quant)
          if q then
            self.length = self.length<TimeWaver.loop_quantization[q] and TimeWaver.loop_quantization[q] or self.length
          end
          self:play()
        end
        self.recording = false
      end,
      
      play = function (self)
        if self.clock_id then return end
        self.playing = true
        self.clock_id = clock.run(
          function (w)
            clock.sync(w.step_quant)
            while true do
              self.phase = w:calc_phase(clock.get_beats()) -- update phase
              local playhead = util.round(self.phase*w.length,w.step_quant)
              if w.steps[playhead] and not w.mute then
                for _,n in pairs(w.steps[playhead]) do
                  local l = n.length*clock.get_beat_sec()
                  w.out:note(n.note,n.vel,l,0)
                end
              end
              clock.sync(w.step_quant)
            end
          end, self)
      end,
      
      stop = function (self)
        if not self.clock_id then return end
        clock.cancel(self.clock_id)
        self.playing, self.clock_id = false, nil
      end,
      
      clear = function (self)
        self.recording, self.playing = false, false
        self.steps = {}
        self.start_beat, self.phase = 0, 0
        self.loop_region = Region()
        if self.clock_id then clock.cancel(self.clock_id) end
        self.clock_id, self.length = nil, nil
      end,
      
      toggle_mode = function (self)
        if BRAIN.transport_state=="stop" then return end
        if not self.recording then self:rec()
        else self:stop_rec() end
      end,
      
      calc_phase = function (self, t)
        local phase = (t-self.start_beat)/self.length 
        if self.loop_region:is_set() then
          local a = (self.loop_region.start-1)/16
          local b = (self.loop_region.out)/16
          phase = a+math.fmod(phase-a,b-a) -- [0,1)
        else
          phase = math.fmod(phase,1) -- [0,1)
        end
        return phase
      end,
      
      draw = function (self,y,buf)
        -- EMPTY ROW
        local row = {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0}
        -- CONTENT
        local l = self.length and self.length or clock.get_beats()-self.start_beat
        for i,s in pairs(self.steps) do
          local x = math.floor(util.linlin(0,l,1,16+1,i))
          row[x] = 2
        end
        -- LOOP REGION
        if self.loop_region:is_set() then
          for x=self.loop_region.start, self.loop_region.out do
            row[x] = row[x] + 1
          end
        end
        -- PLAYHEAD
        local x_s = math.floor(util.linlin(0,1,1,16+1,self.phase))
        local x_e = self.loop_region:wrap(x_s+1,1,16)
        local f = math.fmod(self.phase,1/16)
        row[x_s] = math.floor(util.linlin(0,1/16,(self.mute and 0 or 15),row[x_s],f))
        row[x_e] = math.floor(util.linlin(0,1/16,row[x_e],(self.mute and 0 or 15),f))
        -- SET
        buf:led_level_row(1,y,row)
      end
    }
  end,
  
  new = function (engine_state, _p)
    local tw = engine_template(_p)
    tw.engine_type = TimeWaver
    tw.name = TimeWaver.name
    tw.area = {new_area(1,1,16,4)}
    tw.note_buffer = {}
    tw.view = "wave" -- "wave","time_frame"
    tw.waves = {}
    for w=1,4 do
      tw.waves[w] = TimeWaver.Wave(tw.output, engine_state and engine_state["waves"][w] or nil)
    end
    
    tw.destroy = function (self)
      for _,w in pairs(self.waves) do w:destroy() end
      self = nil
    end
    
    tw.get = function (self)
      return{name=TimeWaver.name, waves=self.waves}
    end
    
    tw.play = function (self)
      for _,w in pairs(self.waves) do
        if w.length then w:play() end
      end
    end
    
    tw.stop = function (self)
      for _,w in pairs(self.waves) do
        w:stop()
      end
    end
    
    tw.note_on = function (self,pitch,vel)
      self.output:note_on(pitch,vel)
      self.note_buffer[pitch] = {note=pitch,vel=vel,beat=clock.get_beats()}
    end
    
    tw.note_off = function (self,pitch,vel)
      self.output:note_off(pitch,vel)
      
      if self.note_buffer[pitch] then
        local msg = self.note_buffer[pitch]        -- get "note_on" msg
        msg.length = clock.get_beats()-msg.beat    -- calculate length
        self.note_buffer[pitch] = nil              -- delete note from buffer
        
        for _,w in pairs(self.waves) do
          if w.recording then w:rec_note(msg) end
        end
      end
    end
    
    tw.grid_event = function (self,e)
      local i = m_index(e,16,5,1,4)
      -- SIDE BUTTONS
      if i then
        if e.type=="click" then
          self.waves[i]:toggle_mode()
        elseif e.type=="double_click"then
          self.waves[i]:clear()
          BRAIN:set_overlay("clear loop")
        elseif e.type=="hold" then
          self.view = "loop_quant"
          BRAIN:set_overlay(self.view)
        elseif e.type=="release" then
          self.view = "wave"
        end
      -- MATRIX
      elseif self.view=="wave" then
        local w = self.waves[e.y]
        if e.type=="double_hold" then
          w:clear_segment(e.x)
        
        elseif e.type=="click" and not w.length and not w.recording and w.loop_quant then
          w.length= e.x*TimeWaver.loop_quantization[w.loop_quant]
          w:play()
          BRAIN:set_overlay("create loop", w.length)
        elseif w.length and (e.type=="press" or e.type=="release" or e.type=="double") then
          w:toggle_loop(e.x)
        end
      elseif self.view=="loop_quant" then
        if e.type=="press" and e.x<9 then
          if e.x>2 then
            self.waves[e.y].loop_quant = e.x-2
            BRAIN:set_overlay("loop quant",TimeWaver.loop_quantization[e.x-2])
          elseif e.x==1 then
            self.waves[e.y].loop_quant = nil
            BRAIN:set_overlay("loop quant","off")
          end
        elseif e.type=="press" and e.x==16 then
          self.waves[e.y].mute = not self.waves[e.y].mute
        end
      end
    end
    
    tw.redraw = function (self, buf)
      self.keys.external_notes = self.output:get_notes()
      
      if self.view=="wave" then
        for y,w in pairs(self.waves) do
          -- SIDE
          local level = w.length and 5 or 2
          level = w.recording and 10 or level
          buf:led_level_set(16,4+y,level)
          -- WAVE
          w:draw(y,buf)
          -- PRE REC
          if not w.length and w.recording and w.start_beat>clock.get_beats() then
            local x = util.round(util.linlin(0,PRE_REC,1,16,w.start_beat-clock.get_beats()),1)
            for i=1,x do buf:led_level_set(i,y,10) end
          end
        end
      elseif self.view=="loop_quant" then
        for y,w in pairs(self.waves) do
          v_radio(buf,3,8,y,w.loop_quant,3,10)
          buf:led_level_set(1,y,w.loop_quant and 3 or 10)
          buf:led_level_set(16,y,w.mute and 3 or 10)
        end
      end
    end
    
    return tw
  end
}

return TimeWaver