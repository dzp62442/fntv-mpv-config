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

local mp = require('mp')
local msg = require('mp.msg')
local mutils = require('./mutils')
local opt = require('mp.options')
local utils = require('mp.utils')

-- 检测模式映射
local DETECT_MODE = {
    CHAPTER = 1, -- 通过章节检测片头片尾
    MANUAL = 2,  -- 通过手动指定片头片尾
    CONTENT = 3, -- 通过内容检测片头片尾，静音/黑屏检测
    AUTO = 4     -- 先通过章节检测，再通过手动指定检测，如果没配置则使用内容检测
}

-- 配置选项定义
local options = {
    -- 基础设置
    enabled = true,
    detect_mode = DETECT_MODE.AUTO, -- auto, chapter, manual, content

    -- 章节检测参数
    min_skip_duration = 10,        -- 最短片头/片尾长度s
    max_skip_duration = 150,       -- 最长片头/片尾长度s
    max_scan_window = 600,          -- 最大扫描窗口（10分钟）
    max_scan_percent = 25,          -- 视频长度百分比

    -- 手动指定片头片尾时间
    manual_intro_start = 0,
    manual_intro_end = 0,
    manual_outro_start = 0,
    manual_outro_end = 0,

    -- 内容检测参数
    silence_threshold = -50,        -- 静音阈值 dB
    silence_min_duration = 2,       -- 最短静音持续时间 s
    black_min_duration = 2,         -- 最短黑屏持续时间 s
    black_threshold = 0.1,          -- 黑屏阈值（0-1之间）
    content_intro_skip_dur = 300,   -- 内容检测参数 片头跳过时间 s
    content_outro_skip_dur = 300,   -- 内容检测参数 片尾跳过时间 s
}

-- 读取配置文件
opt.read_options(options, "smart_skip")

--  通过章节检测片头片尾
local function detect_by_chapters()
    local chapters = mutils.get_chapter_list()
    local D = mutils.dur()
    if not chapters or not D or D <= 0 then return nil end

    local scan_win = math.min(options.max_scan_window, (options.max_scan_percent / 100) * D) -- 前 10 分钟/25% 取小
    -- 寻找片头候选区间（在视频开头部分）
    local intro_candidates = mutils.find_sections_in_window(chapters, 0, scan_win, 
        options.min_skip_duration, options.max_skip_duration)

    -- 寻找片尾候选区间（在视频结尾部分）
    local outro_candidates = mutils.find_sections_in_window(chapters, D - scan_win, D, 
        options.min_skip_duration, options.max_skip_duration)

    -- 如果都没找到符合条件的区间
    if #intro_candidates == 0 and #outro_candidates == 0 then
        return nil
    end

    -- 处理片头：如果有多个候选，优先选择第二个（可能第一个是开场剧情）
    local selected_intro = intro_candidates[2] or intro_candidates[1]

    -- 处理片尾：优先选择最后一个候选（通常最后的章节更可能是真正的片尾）
    local selected_outro = outro_candidates[#outro_candidates]

    -- 返回检测到的片头片尾信息
    return {
        intro = selected_intro and { selected_intro.start_time, selected_intro.end_time } or nil,
        outro = selected_outro and { selected_outro.start_time, selected_outro.end_time } or nil
    }
end

-- 通过手动指定片头片尾
local function detect_by_manual()
    local intro = (options.manual_intro_start >= 0 and options.manual_intro_end > options.manual_intro_start) and
        { options.manual_intro_start, options.manual_intro_end } or nil
    local outro = (options.manual_outro_start >= 0 and options.manual_outro_end > options.manual_outro_start) and
        { options.manual_outro_start, options.manual_outro_end } or nil
    if not intro and not outro then return nil end
    return { intro = intro, outro = outro }
end

-- 通过内容检测片头片尾（静音/黑屏检测）
local function detect_by_content()
    local intro = mutils.detect_silence(0, 5) -- 检测前 5 秒静音
    local outro = mutils.detect_silence(-5, 0) -- 检测后 5 秒静音
    if not intro and not outro then return nil end
    return { intro = intro, outro = outro }
end

local function detect_by_mode()
    if options.detect_mode == DETECT_MODE.CHAPTER then
        return detect_by_chapters()
    elseif options.detect_mode == DETECT_MODE.MANUAL then
        return detect_by_manual()
    elseif options.detect_mode == DETECT_MODE.CONTENT then
        return detect_by_content()
    elseif options.detect_mode == DETECT_MODE.AUTO then
        local result = detect_by_chapters()
        if result then return result end
        result = detect_by_manual()
        if result then return result end
        return detect_by_content()
    else
        msg.error("未知的检测模式")
        return nil
    end
end

-- 智能跳过片头片尾
local function smart_skip()
    if not options.enabled then
        msg.info("智能跳过功能未启用")
        return
    end

    local has_skip_intro = false
    local has_skip_outro = false
    local result = detect_by_mode()

    if not result then
        msg.info("未检测到合适的片头片尾区间")
        return
    end

    -- 监听播放位置以执行跳过
    mp.observe_property("time-pos", "number", function()
        if result.intro and not has_skip_intro then
            has_skip_intro = mutils.skip_if_in(result.intro[1], result.intro[2], "⏭️ 正在跳过片头...")
        end

        if result.outro and not has_skip_outro then
            has_skip_outro = mutils.skip_if_in(result.outro[1], result.outro[2], "⏭️ 正在跳过片尾...")
        end
    end)
end

-- 初始化函数
local function init()
    -- 读取配置文件
    opt.read_options(options, mp.get_script_name())
    
    -- 注册事件处理器
    mp.register_event("file-loaded", smart_skip)
end

-- 启动初始化
init()
