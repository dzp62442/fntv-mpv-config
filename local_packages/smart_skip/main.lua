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
local utils = require('mp.utils')
local msg = require('mp.msg')
local mutils = require('./mutils')

-- 检测模式
local DETECT_MODE = {
    CHAPTER = 1, -- 通过章节检测片头片尾
    MANUAL = 2,  -- 通过手动指定片头片尾
    CONTENT = 3, -- 通过内容检测片头片尾，静音/黑屏检测
    AUTO = 4     -- 先通过章节检测，再通过手动指定检测，如果没配置则使用内容检测
}

-- smart_skip 参数
local detect_enabled = true
local current_detect_mode = DETECT_MODE.AUTO

-- 章节检测参数
local MIN_INTRO_DUR = 10            -- 最短片头长度s
local MAX_INTRO_DUR = 150           -- 最长片头长度s
local MAX_SCAN_WINDOW = 600         -- 最大扫描窗口（10分钟）
local MAX_SCAN_VIDEO_PERCENT = 0.25 -- 视频长度百分比（25%）

-- 手动指定片头片尾时间
local manual_intro = { start_time = 0, end_time = 0 }
local manual_outro = { start_time = 0, end_time = 0 }

--  通过章节检测片头片尾
local function detect_by_chapters()
    local chapters = mutils.get_chapter_list()
    local D = mutils.dur()
    if not chapters or not D or D <= 0 then return nil end

    local scan_win = math.min(MAX_SCAN_WINDOW, MAX_SCAN_VIDEO_PERCENT * D) -- 前 10 分钟/25% 取小
    -- 寻找片头候选区间（在视频开头部分）
    local intro_candidates = mutils.find_sections_in_window(chapters, 0, scan_win, MIN_INTRO_DUR, MAX_INTRO_DUR)

    -- 寻找片尾候选区间（在视频结尾部分）
    local outro_candidates = mutils.find_sections_in_window(chapters, D - scan_win, D, MIN_INTRO_DUR, MAX_INTRO_DUR)

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
    local intro = (manual_intro.start_time >= 0 and manual_intro.end_time > manual_intro.start_time) and
        { manual_intro.start_time, manual_intro.end_time } or nil
    local outro = (manual_outro.start_time >= 0 and manual_outro.end_time > manual_outro.start_time) and
        { manual_outro.start_time, manual_outro.end_time } or nil
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
    if current_detect_mode == DETECT_MODE.CHAPTER then
        return detect_by_chapters()
    elseif current_detect_mode == DETECT_MODE.MANUAL then
        return detect_by_manual()
    elseif current_detect_mode == DETECT_MODE.CONTENT then
        return detect_by_content()
    elseif current_detect_mode == DETECT_MODE.AUTO then
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
            local why = string.format("⏭️ 片头区间: %.1f - %.1f 秒. 正在跳过片头...", result.intro[1], result.intro[2])
            has_skip_intro = mutils.skip_if_in(result.intro[1], result.intro[2], why)
        end

        if result.outro and not has_skip_outro then
            local why = string.format("⏭️ 片尾区间: %.1f - %.1f 秒. 正在跳过片尾...", result.outro[1], result.outro[2])
            has_skip_outro = mutils.skip_if_in(result.outro[1], result.outro[2], why)
        end
    end)
end

-- 在文件加载时也显示章节信息
mp.register_event("file-loaded", smart_skip)
