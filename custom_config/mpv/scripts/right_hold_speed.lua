local mp = require("mp")
local options = require("mp.options")

local opts = {
    key = "RIGHT",
    seek_seconds = 5,
    hold_delay = 0.16,
    speed = 2.0,
    ramp = true,
    ramp_step = 0.25,
    ramp_interval = 0.03,
    restore_step = 0.35,
    restore_interval = 0.02,
    show_osd = true,
    hold_osd_interval = 0.3,
    hold_osd_duration = 0.6,
}

options.read_options(opts, "right_hold_speed")

local pressed = false
local speeding = false
local saved_speed = 1.0
local hold_timer = nil
local ramp_timer = nil
local osd_timer = nil
local ignore_press_until = 0

local function kill_timer(timer)
    if timer then
        timer:kill()
    end
end

local function clear_hold_timer()
    kill_timer(hold_timer)
    hold_timer = nil
end

local function clear_ramp_timer()
    kill_timer(ramp_timer)
    ramp_timer = nil
end

local function clear_osd_timer()
    kill_timer(osd_timer)
    osd_timer = nil
end

local function set_speed(value)
    mp.set_property_number("speed", math.max(0.01, value))
end

local function show(message, duration)
    if opts.show_osd then
        mp.osd_message(message, duration or 0.6)
    end
end

local function show_hold_speed()
    show(string.format("%.1fx", opts.speed), opts.hold_osd_duration)
end

local function start_hold_osd()
    clear_osd_timer()
    show_hold_speed()
    osd_timer = mp.add_periodic_timer(opts.hold_osd_interval, show_hold_speed)
end

local function stop_hold_osd()
    clear_osd_timer()
end

local function ramp_to(target, step, interval)
    clear_ramp_timer()

    if not opts.ramp then
        set_speed(target)
        return
    end

    local done = false

    local function tick()
        local current = mp.get_property_number("speed", target)
        local diff = target - current

        if math.abs(diff) <= step then
            set_speed(target)
            done = true
            clear_ramp_timer()
            return
        end

        if diff > 0 then
            set_speed(current + step)
        else
            set_speed(current - step)
        end
    end

    tick()
    if done then
        return
    end
    ramp_timer = mp.add_periodic_timer(interval, tick)
end

local function seek_forward()
    mp.commandv("seek", tostring(opts.seek_seconds), "relative", "exact")
    show("+" .. tostring(opts.seek_seconds) .. "s", 0.35)
end

local function start_fast_forward()
    hold_timer = nil

    if not pressed or speeding then
        return
    end

    speeding = true
    saved_speed = mp.get_property_number("speed", 1.0)

    start_hold_osd()
    ramp_to(opts.speed, opts.ramp_step, opts.ramp_interval)
end

local function stop_fast_forward()
    clear_hold_timer()

    if not speeding then
        return
    end

    speeding = false
    stop_hold_osd()
    ramp_to(saved_speed, opts.restore_step, opts.restore_interval)
    show(string.format("%.1fx", saved_speed), 0.4)
end

local function on_right(event)
    local name = event.event
    local now = mp.get_time()

    if name == "down" then
        if pressed then
            return
        end

        pressed = true
        speeding = false
        clear_hold_timer()
        hold_timer = mp.add_timeout(opts.hold_delay, start_fast_forward)
    elseif name == "repeat" then
        if pressed and not speeding then
            start_fast_forward()
        end
    elseif name == "up" then
        if not pressed then
            return
        end

        pressed = false

        if speeding then
            stop_fast_forward()
        else
            clear_hold_timer()
            seek_forward()
        end

        ignore_press_until = now + 0.1
    elseif name == "press" then
        if now >= ignore_press_until then
            seek_forward()
        end
    end
end

mp.add_forced_key_binding(opts.key, "right_hold_speed", on_right, {
    complex = true,
    repeatable = true,
})
