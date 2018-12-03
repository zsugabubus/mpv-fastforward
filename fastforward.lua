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
)       script-binding fastforward/speedup
# reduce speed
(       script-binding fastforward/slowdown
# Pro tip: Use `BACKSPACE` to stop fast-forwarding immediately.
```

]]

options = require 'mp.options'
msg = require 'mp.msg'

--[[
This default config makes absolutely no sense, so use `script-opts/fastforward.conf` to change these values.
You can also use expressions like [+-*/]{number}, e.g. /2, *0.5, +1, -0.3...
]]
local opts = {
    speed_increase = "+0.2", --    <--  here...
    -- Upper speed limit.
    max_speed = 8, 
    -- Time to elapse until first slow down.
    decay_delay = 2, 
    -- If you don't change the playback speed for `decay_delay` seconds,
    -- it will be decreased by `speed_decrease` at every
    -- `decay_interval` seconds automatically.
    decay_interval = 0.5,
    speed_decrease = "*0.9", -- <--        ...and here.
}

options.read_options(opts)

local timer = nil
local paused

local function pause()
    msg.debug("pause fast-forwarding")
    if timer ~= nil then timer:stop() end
end

local function resume()
    msg.debug("resume fast-forwarding")
    if timer ~= nil then timer:resume() end
end

local function on_pause_change(_, pause)
    if pause then
        pause()
    else
        resume()
    end
end

local function on_speed_change(_, speed)
    if speed <= 1.001 then
        msg.debug("stop fast-forwarding")

        timer:kill()
        timer = nil

        mp.unobserve_property(on_pause_change)
        mp.unobserve_property(on_speed_change)
        mp.remove_key_binding("slowdown")

        mp.set_property_bool("pause", paused)
        mp.set_property_number("speed", 1)

        mp.osd_message("Speed: 1")
    elseif speed > opts.max_speed then
        -- clamp speed
        mp.set_property_number("speed", opts.max_speed)
        mp.osd_message("▶▶ x"..opts.max_speed)
    else
        mp.osd_message("▶▶ x"..string.format("%.2f", speed), 10)
    end
end

local function change_speed(amount)
    local speed = mp.get_property_number("speed")
    local op = amount:sub(1, 1)
    local val = tonumber(amount:sub(2))

    if     op == "+" then speed = speed + val
    elseif op == "-" then speed = speed - val
    elseif op == "*" then speed = speed * val
    elseif op == "/" then speed = speed / val
    else msg.warn("unable to parse value: `" .. amount .. "'")
    end

    mp.set_property_number("speed", speed)
end

local function slow_down()
    change_speed(opts.speed_decrease)
end

local function begin_slow_down()
    msg.trace("begin_slow_down()")
    slow_down()
    timer = mp.add_periodic_timer(opts.decay_interval, slow_down)
end

local function speed_up()
    local speed = mp.get_property_number("speed")

    if opts.decay_delay > 0 and opts.decay_interval > 0 then
        if timer ~= nil then timer:kill() end
        timer = mp.add_timeout(opts.decay_delay, begin_slow_down)
    end

    change_speed(opts.speed_increase)

    if speed == 1 then
        msg.debug("start fast-forwarding")
        paused = mp.get_property_bool("pause")
        mp.observe_property("pause", "bool", on_pause_change)
        mp.observe_property("speed", "number", on_speed_change)
        mp.add_key_binding("(", "slowdown", slow_down, {repeatable=true})

        mp.set_property_bool("pause", false)
    end
end

mp.add_key_binding(")", "speedup", speed_up, {repeatable=true})

-- vim: expandtab ts=4 sw=4
