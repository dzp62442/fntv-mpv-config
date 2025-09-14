-- autosize.lua
-- 根据显示器分辨率自动调整 mpv 窗口大小和位置
-- 对于宽度 > 2560px 的显示器（2K以上），设置为 1920x1080 并居中显示
-- 否则设置为 1280x720 并居中显示
-- 只在第一次启动时生效，不会在切换上下集时强制居中

local applied = false

mp.register_event("start-file", function()
    if applied then
        return -- 已经调整过，不再重复
    end
    local dw = mp.get_property_number("display-width")
    local dh = mp.get_property_number("display-height")
    local ww, wh
    if dw > 2560 then
        ww, wh = 1920, 1080
    else
        ww, wh = 1280, 720
    end
    local x = math.floor((dw - ww) / 2)
    local y = math.floor((dh - wh) / 2)
    mp.set_property("geometry", string.format("%dx%d+%d+%d", ww, wh, x, y))
    applied = true
end)
