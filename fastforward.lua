--[[ fastforward.lua

# Examples

* `script-opts/fastforward.lua`:
```config
max_speed=3
speed_increase=*1.2
speed_decrease=/1.1
```

* `input.conf`:
```config
# make playback faster
)     script-binding fastforward/speedup
# reduce speed
(     script-binding fastforward/slowdown
# Pro tip: Use `BACKSPACE` to stop fast-forwarding immediately.
```

]]

local options = require 'mp.options'

--[[
This default config makes absolutely no sense, so use `script-opts/fastforward.conf` to change these values.
You can also use expressions like [+-*/]{number}, e.g. /2, *0.5, +1, -0.3...
]]
local opts = {
speed_increase = '+0.2', --  <--  here...
  -- Upper speed limit.
  max_speed = 8,
  -- Time to elapse until first slow down.
  decay_delay = 2,
  -- If you don't change the playback speed for `decay_delay` seconds,
  -- it will be decreased by `speed_decrease` at every
  -- `decay_interval` seconds automatically.
  decay_interval = 0.5,
  speed_decrease = '*0.9', -- <--    ...and here.
}

options.read_options(opts)

local timer = nil
local was_paused

local function pause_changed(_, paused)
  if paused then
    timer:stop()
  else
    timer:resume()
  end
end

local function speed_changed(_, speed)
  if speed <= 1.001 then
    mp.unobserve_property(pause_changed)
    mp.unobserve_property(speed_changed)

    timer:kill()
    timer = nil

    mp.remove_key_binding('slowdown')

    mp.set_property_bool('pause', was_paused)
    speed = 1
  elseif speed > opts.max_speed then
    speed = opts.max_speed
  end

  mp.set_property_number('speed', speed)
  if speed == 1 then
    mp.osd_message('')
  else
    mp.osd_message(('▶▶ x%.2f'):format(speed), 10)
  end
end

local function change_speed(amount)
  local new_speed = mp.get_property_number('speed')
  local op = amount:sub(1, 1)
  local val = tonumber(amount:sub(2))

  if     op == '+' then new_speed = new_speed + val
  elseif op == '-' then new_speed = new_speed - val
  elseif op == '*' then new_speed = new_speed * val
  elseif op == '/' then new_speed = new_speed / val
  else new_speed = tonumber(amount)
  end

  mp.set_property_number('speed', new_speed)
end

local function slow_down()
  change_speed(opts.speed_decrease)
end

local function auto_slow_down()
  slow_down()
  timer = mp.add_periodic_timer(opts.decay_interval, slow_down)
end

local function speed_up()
  change_speed(opts.speed_increase)

  if timer == nil then
    mp.observe_property('pause', 'bool', pause_changed)
    mp.observe_property('speed', 'number', speed_changed)
    mp.add_key_binding('(', 'slowdown', slow_down, {repeatable=true})
    was_paused = mp.get_property_bool('pause')
    mp.set_property_bool('pause', false)
  else
    timer:kill()
  end
  timer = mp.add_timeout(opts.decay_delay, auto_slow_down)
end

mp.add_key_binding(')', 'speedup', speed_up, {repeatable=true})
