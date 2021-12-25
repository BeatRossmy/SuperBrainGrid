-- SUPER_BRAIN
-- v2.0.0 @beat
-- https://llllllll.co/t/superbrain-multi-engine-midi-sequencer/44781
--
-- 4 track multi-engine SEQ
--
-- TARGETS:
-- sc engine (internal)
-- midi (usb)
-- cv/gate (crow)
-- disting EX (crow->ii)
-- midi (crow->ii->disting)
--
-- ENGINES:
-- ^  4 head graph sequencer
-- #  4 cascading counters
-- ~  4 track looper
-- =  4 

hs = include('/awake/lib/halfsecond')

 -- LOAD STUFF
Buffer = require 'gridbuf'
MusicUtil = require 'musicutil'
tabutil = include('lib/misc/tabutil')
include('lib/misc/helper_functions')

-- CONNECT TO GRID AND CHECK IF CROW IS CONNECTED
crow_connected = norns.crow.connected()
g = grid.connect()

-- SC ENGINE SETUP
engine.name = "PolyPerc"
include('lib/poly_fork')
Poly_Fork.engine_on = function (pitch,vel)
  engine.amp(util.linlin(0,1.27,0.05,1,vel))
  engine.hz(MusicUtil.note_num_to_freq(pitch))
end
Poly_Fork.engine_off = function (pitch,vel) end

add_engine_params = function ()
  params:add_separator()
  params:add_group("engine",5)
  
  cs_PW = controlspec.new(0,100,'lin',0,50,'%')
  params:add{type="control",id="pw",controlspec=cs_PW,
    action=function(x) engine.pw(x/100) end}

  cs_REL = controlspec.new(0.1,3.2,'lin',0,1.2,'s')
  params:add{type="control",id="release",controlspec=cs_REL,
    action=function(x) engine.release(x) end}

  cs_CUT = controlspec.new(50,5000,'exp',0,800,'hz')
  params:add{type="control",id="cutoff",controlspec=cs_CUT,
    action=function(x) engine.cutoff(x) end}

  cs_GAIN = controlspec.new(0,4,'lin',0,1,'')
  params:add{type="control",id="gain",controlspec=cs_GAIN,
    action=function(x) engine.gain(x) end}
  
  cs_PAN = controlspec.new(-1,1, 'lin',0,0,'')
  params:add{type="control",id="pan",controlspec=cs_PAN,
    action=function(x) engine.pan(x) end}
end

include('lib/brain')
BRAIN = Brain(g)

-- MENU_ENC = 0

function init()
  -- Create data directory if it doesn't exist
  if not util.file_exists(_path.data.."SUPER_BRAIN_GRID/") then
    util.make_dir(_path.data.."SUPER_BRAIN_GRID/")
    print("Made SUPER_BRAIN_GRID data directory")
  end
  
  add_engine_params()

  setup_device_slots()
  
  BRAIN:init()
  BRAIN:set_visible(1)
  
  local auto_connected_devices = {"K-Board","Launchpad X 2"}
  
  for _,m in pairs(midi_slots) do
    if tabutil.contains(auto_connected_devices,m.name) then
      tabutil.print(m)
      print(m.name.." detected")
      
      external_midi_controller = m
      
      -- LINK TO ISO
      m.device.event = function(data)
        local msg = midi.to_msg(data)
        if msg.type == "note_on" then
          BRAIN.keys:note(msg.note,msg.vel)
        elseif msg.type == "note_off" then
          BRAIN.keys:note(msg.note,0)
        end
      end
    end
  end
  
  clock.run(function () while true do redraw() clock.sleep(1/24) end end)
  
  hs.init()
end

function key(n,z)
  print(n,z)
  if n==1 and z==1 then
    -- print("play")
    -- BRAIN:play_stop()
    local state = BRAIN.transport_state
    if state == "stop" then clock.transport.start()
    elseif state ~= "stop" then clock.transport.stop() end
  end
end

--[[
function key(n,z)
  if n==1 and z==1 then
    if BRAIN.ui_mode == "apps" then BRAIN.ui_mode = "settings"
    else BRAIN.ui_mode = "apps" end
    print(BRAIN.ui_mode)
  elseif n==2 then
    MENU_ENC = 1
    BRAIN.help = z==1
  end
end

function enc(n,d)
  MENU_ENC = util.clamp(MENU_ENC+d,1,10)
end--]]

function redraw()
  screen:clear()
  BRAIN:redraw_screen()
  screen:update()
end

function cleanup()
  BRAIN:cleanup()
  BRAIN = nil
  for cl_id,_ in pairs(clock.threads) do clock.cancel(cl_id) end
end