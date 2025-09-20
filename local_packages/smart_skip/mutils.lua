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

local mutils = {}

function mutils.to_json(tbl)
    -- utils.format_json 成功时返回 1 个值；失败时返回 (nil, "error")
    local s, err = utils.format_json(tbl)
    if not s then return nil, err end
    return s
end

function mutils.dur() return mp.get_property_number('duration', 0) or 0 end

function mutils.timepos() return mp.get_property_number('time-pos', 0) or 0 end

-- 在OSD上显示消息，同时记录到日志
function mutils.show_message(text, duration)
    duration = duration or 3 -- 默认显示3秒
    -- 设置OSD样式和对齐方式
    local ass = mp.get_property_osd("osd-ass-cc/0")
    -- {\\an1} 表示左下角对齐，{\\an2} 表示底部居中对齐
    local styled_text = ass .. "{\\an1}" .. text
    mp.osd_message(styled_text, duration)
    msg.info(text)
end

-- 获取章节列表
function mutils.get_chapter_list()
    local chapters = mp.get_property_native('chapter-list')
    if not chapters then return nil end
    return chapters
end

-- 跳过一次：如果当前位置在 [a,b) 内，立即 seek 到 b
function mutils.skip_if_in(a, b, why)
    local curr_pos = mutils.timepos()
    if curr_pos >= a and curr_pos < b then
        mutils.show_message(why, 2)
        mp.set_property_number('time-pos', b)
        return true
    end
    return false
end

-- 在指定时间窗口内寻找符合时长条件的连续章节区间
function mutils.find_sections_in_window(chapters, start_time, end_time, min_dur, max_dur)
    local candidates = {}

    for i = 1, #chapters do
        local chapter = chapters[i]
        -- 确保章节在指定时间窗口内
        if chapter.time > end_time then break end
        
        local next_chapter = chapters[i + 1]
        if next_chapter then
            local duration = next_chapter.time - chapter.time
            if duration >= min_dur and duration <= max_dur then
                table.insert(candidates, {
                    start_time = chapter.time,
                    end_time = next_chapter.time,
                    duration = duration
                })
            end
        end
    end

    return candidates
end

-- 获取anime的
return mutils
