--[[
MIT License

Copyright (c) 2025 Tag mig hånden

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

GitHub: https://github.com/QiaoKes/fntv-mpv-config
]]
local msg         = require('mp.msg')
local utils       = require('mp.utils')
local api         = require("./api")
local mutils      = require("./mutils")

-- 你的配置模块（需导出 opts / DETECT_MODE）
local options_mod = require("./options")
local opts        = options_mod.opts
local DETECT_MODE = options_mod.DETECT_MODE
local SCRIPT      = mp.get_script_name()

-- ========= 工具 =========
local function mode_name(m)
    if m == DETECT_MODE.CHAPTER then return "章节模式" end
    if m == DETECT_MODE.MANUAL then return "手动模式" end
    if m == DETECT_MODE.AUTO then return "自动模式" end
    return tostring(m)
end

local function bool_sign(b) return b and "✔" or "X" end

local function reopen_main()
    open_skip_menu_uosc()
end

local function update_menu_uosc(menu_type, menu_title, menu_item, menu_footnote, menu_cmd, query)
    local items = {}
    if type(menu_item) == "string" then
        table.insert(items, {
            title = menu_item,
            value = "",
            italic = true,
            keep_open = true,
            selectable = false,
            align = "center",
        })
    else
        items = menu_item
    end

    local menu_props = {
        type              = menu_type,
        title             = menu_title,
        -- 关键：有 menu_cmd 就是 palette，提交触发 on_search
        search_style      = menu_cmd and "palette" or "on_demand",
        search_debounce   = menu_cmd and "submit" or 0,
        on_search         = menu_cmd, -- 这里会把 JSON 事件传给我们
        footnote          = menu_footnote,
        search_suggestion = query,
        items             = items,
    }
    local json_props = utils.format_json(menu_props)
    mp.commandv("script-message-to", "uosc", "open-menu", json_props)
end

-- ========= 主菜单（uosc） =========
function open_skip_menu_uosc()
    local items = {}

    table.insert(items, {
        title = string.format("跳过功能：%s", bool_sign(opts.enabled)),
        bold = true,
        italic = true,
        keep_open = true,
        selectable = false
    })

    table.insert(items, {
        title = opts.enabled and "关闭" or "开启",
        hint = "总开关",
        value = { "script-message-to", SCRIPT, "toggle-skip-enabled" },
        keep_open = true,
        selectable = true,
    })

    table.insert(items, { title = "— 模式选择 —", keep_open = true, selectable = false })
    local modes = {
        { id = DETECT_MODE.AUTO, name = "自动模式", hint = "优先章节，无则回退手动指定" },
        { id = DETECT_MODE.CHAPTER, name = "章节模式", hint = "通过章节自动识别" },
        { id = DETECT_MODE.MANUAL, name = "手动模式", hint = "手动指定片头片尾" },
    }

    for _, m in ipairs(modes) do
        table.insert(items, {
            title = (opts.detect_mode == m.id and "● " or "○ ") .. m.name,
            hint = m.hint,
            value = { "script-message-to", SCRIPT, "set-mode", tostring(m.id) },
            keep_open = true,
            selectable = true,
        })
    end

    table.insert(items, { title = "— 手动时间（秒） —", keep_open = true, selectable = false })

    -- 片头结束：打开一个 palette 输入菜单（真正的输入框）
    table.insert(items, {
        title = string.format("片头时长：%s", tostring(opts.manual_intro_end or 0)),
        hint = "输入整数（秒）后回车",
        value = { "script-message-to", SCRIPT, "open-intro-input" },
        keep_open = true,
        selectable = true,
    })

    -- 片尾开始：同上
    table.insert(items, {
        title = string.format("片尾时长：%s", tostring(opts.manual_outro_end - opts.manual_outro_start)),
        hint = "输入整数（秒）后回车",
        value = { "script-message-to", SCRIPT, "open-outro-input" },
        keep_open = true,
        selectable = true,
    })

    update_menu_uosc(
        "menu_skip",
        "跳过片头片尾设置",
        items,
        "提示：回车提交；Esc 返回",
        nil,
        nil
    )
end

-- ========= palette 输入子菜单（与 sample.lua 同形） =========
local function open_number_palette(menu_type, title, hint, on_event, placeholder)
    local foot = "请输入整数（单位：秒），按 Enter 提交"
    local cmd  = { "script-message-to", SCRIPT, on_event } -- uosc val on_event
    update_menu_uosc(menu_type, title, hint, foot, cmd, placeholder)
end

local function open_intro_input_uosc()
    local val = tostring(opts.manual_intro_end)
    if val == "0" then val = "" end
    open_number_palette("menu_intro", "设置片头时长（秒）", "等待输入…", "set-intro-end", val)
end

local function open_outro_input_uosc()
    local val = tostring(opts.manual_outro_end - opts.manual_outro_start)
    if val == "0" then val = "" end
    open_number_palette("menu_outro", "设置片尾时长（秒）", "等待输入…", "set-outro-start", val)
end


mp.commandv("script-message-to", "uosc", "set-button", "skip_cfg_btn", utils.format_json({
    icon = "settings",
    tooltip = "跳过设置",
    command = "script-message open-skip-menu",
}))

-- ========= 菜单交互脚本消息 =========
mp.register_script_message("open-skip-menu", open_skip_menu_uosc)

mp.register_script_message("toggle-skip-enabled", function()
    opts.enabled = not opts.enabled
    msg.info("跳过功能：" .. bool_sign(opts.enabled))
    mutils.save_options()
    reopen_main()
end)

mp.register_script_message("set-mode", function(mode_str)
    local m = tonumber(mode_str)
    if not m then return end
    opts.detect_mode = m
    msg.info("检测模式 => " .. mode_name(m))
    mutils.save_options()
    reopen_main()
end)

mp.register_script_message("open-intro-input", open_intro_input_uosc)

mp.register_script_message("open-outro-input", open_outro_input_uosc)

mp.register_script_message("set-intro-end", function(val)
    local n = tonumber(val)
    if n and n >= 0 and n == math.floor(n) and n <= opts.manual_outro_end then
        opts.manual_intro_end = n
        msg.info("片头时长 => " .. n .. " 秒")
        local play_url = mp.get_property("path")
        api.set_skip_time(play_url, opts.manual_intro_end, opts.manual_outro_end - opts.manual_outro_start)
        reopen_main()
    else
        open_number_palette("menu_intro", "设置片头时长（秒）", "无效输入", "set-intro-end", val)
    end
end)

mp.register_script_message("set-outro-start", function(val)
    local n = tonumber(val)
    if n and n >= 0 and n == math.floor(n) and n <= opts.manual_outro_end then
        opts.manual_outro_start = opts.manual_outro_end - n
        msg.info("片尾时长 => " .. n .. " 秒")
        local play_url = mp.get_property("path")
        api.set_skip_time(play_url, opts.manual_intro_end, opts.manual_outro_end - opts.manual_outro_start)
        reopen_main()
    else
        open_number_palette("menu_outro", "设置片尾时长（秒）", "无效输入", "set-outro-end", val)
    end
end)
