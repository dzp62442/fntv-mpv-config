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
local api = require('./api')

-- 检测模式映射
local DETECT_MODE = {
    CHAPTER = 1, -- 通过章节检测片头片尾
    MANUAL = 2,  -- 通过手动指定片头片尾
    AUTO = 3     -- 先通过章节检测，再通过手动指定检测
}

-- 配置选项定义
local options = {
    -- 基础设置
    enabled = true,
    detect_mode = DETECT_MODE.AUTO, -- auto, chapter, manual, content

    -- 章节检测参数
    min_skip_duration = 10,  -- 最短片头/片尾长度s
    max_skip_duration = 150, -- 最长片头/片尾长度s
    max_scan_window = 600,   -- 最大扫描窗口（10分钟）
    max_scan_percent = 25,   -- 视频长度百分比

    -- 手动指定片头片尾时间, 从服务器获取，不允许在配置文件设置
    manual_intro_start = 0,
    manual_intro_end = 0,
    manual_outro_start = 0,
    manual_outro_end = 0,
}

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

    -- 处理片尾：如果有多个候选，优先选择第一个（可能最后一个是结尾剧情）
    local selected_outro = outro_candidates[1]

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

local function detect_by_mode()
    if options.detect_mode == DETECT_MODE.CHAPTER then
        return detect_by_chapters()
    elseif options.detect_mode == DETECT_MODE.MANUAL then
        return detect_by_manual()
    elseif options.detect_mode == DETECT_MODE.AUTO then
        local result = detect_by_chapters()
        if result then return result end
        result = detect_by_manual()
        if result then return result end
        return nil
    else
        msg.error("未知的检测模式")
        return nil
    end
end

-- 读取服务器配置
local function load_server_config()
    local play_url = mp.get_property("path")
    api.get_skip_time(play_url, function(resp, err)
        if err or not resp or resp.code ~= 0 then
            msg.error("获取服务器跳过时间点失败: " .. err)
            return
        end
        local data = resp.data
        if data then
            options.manual_intro_start = 0
            options.manual_intro_end = data.skipStart or 0
            local total_dur = mutils.dur()
            options.manual_outro_start = total_dur - data.skipEnd
            options.manual_outro_end = total_dur
            msg.info(string.format("服务器跳过时间点: 片头 %d - %d 秒, 片尾 %d - %d 秒",
                options.manual_intro_start, options.manual_intro_end,
                options.manual_outro_start, options.manual_outro_end))
        end
    end)
end

-- 智能跳过片头片尾
local function smart_skip()
    load_server_config()

    local has_skip_intro = false
    local has_skip_outro = false
    local result = nil

    -- 监听播放位置以执行跳过
    mp.observe_property("time-pos", "number", function(_, curr_pos)
        if not options.enabled then
            return
        end

        if not result then
            result = detect_by_mode()
        end

        if not has_skip_intro and result and result.intro then
            has_skip_intro = mutils.skip_if_in(curr_pos, result.intro[1], result.intro[2], "⏭️ 正在跳过片头...")
            if has_skip_intro then
                msg.info("检测到片头: " .. utils.to_string(result.intro))
            end
        end

        if not has_skip_outro and result and result.outro then
            has_skip_outro = mutils.skip_if_in(curr_pos, result.outro[1], result.outro[2], "⏭️ 正在跳过片尾...")
            if has_skip_outro then
                msg.info("检测到片尾: " .. utils.to_string(result.outro))
            end
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
