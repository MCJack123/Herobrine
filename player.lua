for i = 0, 15 do term.setPaletteColor(2^i, term.nativePaletteColor(2^i)) end
package.path = package.path .. ";/lib/?.lua"
local M6502 = require "M6502"
local SID = require "sid"
local dfpwm = require "cc.audio.dfpwm"
local blt = require "betterblittle"
local util = require "util"
local mem = setmetatable({}, {__index = function() return 0 end})
local file = assert(fs.open("/assets/music.sid", "rb"))
local magicID = file.read(4)
if magicID ~= "RSID" and magicID ~= "PSID" then file.close() error("Not a SID file") end
local version, dataOffset, loadAddress, initAddress, playAddress, nsongs, defaultsong, speed, name, author, released = (">HHHHHHHIc32c32c32"):unpack(file.read(0x72))
if not name or not author or not released then file.close() error("Invalid SID file") end
name, author, released = name:gsub("%z+$", ""), author:gsub("%z+$", ""), released:gsub("%z+$", "")
local ntsc, sidModel = false, SID.chip_model.MOS6581
if version >= 2 or magicID == "RSID" then
    local flags
    flags = (">HBBBB"):unpack(file.read(6))
    ntsc, sidModel = bit32.btest(flags, 0x0008), bit32.btest(flags, 0x0020) and SID.chip_model.MOS8580 or SID.chip_model.MOS6581
end
file.seek("set", dataOffset)
if loadAddress == 0x0000 then loadAddress = ("<H"):unpack(file.read(2)) end
if initAddress == 0x0000 then initAddress = loadAddress end
if defaultsong == 0 then defaultsong = 1 end
do
    local addr = loadAddress
    for s in file.read, nil do
        mem[addr] = s
        addr = addr + 1
    end
end
file.close()

local cpu = M6502.new()
cpu:power(true)
local cpufreq = ntsc and 1022727 or 985248
local sid = {SID:new()}
sid[1]:set_chip_model(sidModel)
sid[1]:set_sampling_parameters(cpufreq, SID.sampling_method.SAMPLE_FAST, 48000)
function cpu:read(addr)
    if addr == 0x02A6 then return ntsc and 0 or 1 end
    if bit32.band(addr, 0xFC00) == 0xD400 then return sid[1]:read(bit32.band(addr, 0x001F)) end
    return mem[addr]
end
function cpu:write(addr, val)
    if bit32.band(addr, 0xFC00) == 0xD400 then sid[1]:write(bit32.band(addr, 0x001F), val)
    else mem[addr] = val end
end

local song = tonumber(select(2, ...) or nil) or defaultsong
local speaker = assert(peripheral.find("speaker"), "Please attach a speaker.")
sid[1].extfilt:enable_filter(true)
cpu.state.a = song
cpu:call(initAddress)
term.setBackgroundColor(colors.black)
term.setTextColor(colors.lime)
term.clear()
term.setCursorPos(1, 1)
write("PRE-LOAD INIT...")
term.setCursorBlink(true)
local nextChunk
do
    local start = os.epoch "utc"
    local data = {}
    while #data < 48000 do
        cpu.state.pc = 0
        cpu:call(playAddress, 19705)
        sid[1]:clock(cpufreq / 50, data, #data + 1, 48000)
    end
    for i = 1, #data do data[i] = math.floor(data[i] / 256) end
    local time = os.epoch "utc" - start
    term.setCursorBlink(false)
    if time >= 750 then
        -- Pre-load all music
        file = assert(fs.open("/assets/loading.mus", "rb"))
        local baseSize, residueSize = ("<HH"):unpack(file.read(4))
        local base = file.read(baseSize):gsub("([\x55\xAA])(.)", function(s, n) return s:rep(n:byte()) end)
        local residue = file.read(residueSize):gsub("(\x80)(.)", function(s, n) return s:rep(n:byte()) end)
        file.close()
        local loading_chunks = {}
        local decoder = dfpwm.make_decoder()
        local min, max, floor = math.min, math.max, math.floor
        for i = 1, #residue, 48000 do
            local d = {residue:byte(i, i + 47999)}
            local b = decoder(base:sub(i / 48, i / 48 + 999))
            for j = 1, #d, 6 do
                local a = (j - 1) / 6 + 1
                local x, y = b[a] or 0, b[a+1] or b[a] or 0
                d[j] = min(max(d[j] - 128 + x, -128), 127)
                d[j+1] = min(max((d[j+1] or 0) - 128 + floor(x * 5/6 + y * 1/6), -128), 127)
                d[j+2] = min(max((d[j+2] or 0) - 128 + floor(x * 4/6 + y * 2/6), -128), 127)
                d[j+3] = min(max((d[j+3] or 0) - 128 + floor(x * 3/6 + y * 3/6), -128), 127)
                d[j+4] = min(max((d[j+4] or 0) - 128 + floor(x * 2/6 + y * 4/6), -128), 127)
                d[j+5] = min(max((d[j+5] or 0) - 128 + floor(x * 1/6 + y * 5/6), -128), 127)
            end
            loading_chunks[#loading_chunks+1] = d
        end
        local length
        parallel.waitForAny(function()
            while true do
                for i = 1, #loading_chunks do
                    speaker.playAudio(loading_chunks[i], 0.5)
                    length = #loading_chunks[i] / 48
                    os.pullEvent("speaker_audio_empty")
                end
            end
        end, function()
            -- guess the length I guess?
            local start = os.epoch "utc"
            local w, h = term.getSize()
            local centerX, centerY = math.floor(w / 2), math.floor(h / 2)
            term.clear()
            term.setTextColor(colors.white)
            local function centerWrite(y) return function(text)
                term.setCursorPos(math.ceil(centerX - (#text / 2) + 1), centerY + y)
                term.write(text)
            end end
            local function rgb(xx)
                local r = (math.max(math.abs(3.0*xx - 1.5) - 0.5, 0.0)) * 0.6 + 0.2
                local g = (math.max(1 - math.abs(3.0*xx - 1), 0.0)) * 0.6 + 0.2
                local b = (math.max(1 - math.abs(3.0*xx - 2), 0.0)) * 0.6 + 0.2
                return r, g, b
            end
            centerWrite(-1) "Loading music..."
            centerWrite(0) "(CraftOS-PC can speed this up!)"
            local progress = window.create(term.current(), math.ceil(centerX - (45 / 2) + 1), centerY + 2, 45, 1)
            progress.setBackgroundColor(16384)
            progress.clear()
            progress.setCursorPos(1, 1)
            for i = 1, 13 do term.setPaletteColor(2^i, rgb((i - 1) / 13)) end
            term.setPaletteColor(16384, term.nativePaletteColor(colors.gray))
            local offset = 0
            local chunks = {data}
            local prog = 1
            for c = 2, 150 do
                local data = {}
                chunks[c] = data
                while #data < 48000 do
                    cpu.state.pc = 0
                    cpu:call(playAddress, 19705)
                    sid[1]:clock(cpufreq / 50, data, #data + 1, 48000)
                    if os.epoch "utc" - start >= length then
                        os.pullEvent("speaker_audio_empty")
                        start = os.epoch "utc"
                    end
                    offset = (offset - 0.005) % 1
                    for i = 1, 13 do term.setPaletteColor(2^i, rgb(((i - 1) / 13 + offset) % 1)) end
                end
                for i = 1, #data do data[i] = math.floor(data[i] / 256) end
                if math.floor(c / 150 * 45) > prog then progress.blit(" ", "f", ("%x"):format((c / 2) % 13 + 1)) prog = prog + 1 end
            end
            local n = 0
            nextChunk = function()
                n = n + 1
                return chunks[n]
            end
        end)
        os.pullEvent("speaker_audio_empty")
        for i = 0, 15 do term.setPaletteColor(2^i, term.nativePaletteColor(2^i)) end
    else
        if time >= 700 then
            -- Disable filter for small time savings
            sid[1].extfilt:enable_filter(false)
        end
        nextChunk = function()
            if data then
                local a = data
                data = nil
                return a
            end
            local start = os.epoch "utc"
            local data = {}
            while #data < 48000 do
                cpu.state.pc = 0
                cpu:call(playAddress, 19705)
                sid[1]:clock(cpufreq / 50, data, #data + 1, 48000)
                if os.epoch "utc" - start >= 35 then -- time budget for other code = 15ms (how much do I need???)
                    sleep(0)
                    start = os.epoch "utc"
                end
            end
            for i = 1, #data do data[i] = math.floor(data[i] / 256) end
            return data
        end
    end
end

local num = 0
local start
local chunk
local running = true
parallel.waitForAll(function()
    os.queueEvent("speaker_audio_empty")
    while running do
        chunk = nextChunk()
        if not chunk then return end
        os.pullEvent("speaker_audio_empty")
        speaker.playAudio(chunk, 3)
        start = os.epoch "utc" - num * 1000 - (_HOST:match "CraftOS%-PC" and 1000 or -1000)
        num = num + 1
    end
end, function()
    local function sync(n)
        while num < math.floor(n) do os.pullEvent("speaker_audio_empty") end
        while os.epoch "utc" - start < n * 1000 do sleep(0.05) end
    end
    shell.run("parts/intro")
    local w, h = term.getSize()
    local main = window.create(term.current(), 1, 1, w, h)
    local mask = window.create(term.current(), 1, 1, w, h)
    local z = ("\0"):rep(w)
    for y = 1, h do mask.setCursorPos(1, y) mask.blit(z, z, z) end
    local graph = window.create(mask, 1, math.ceil(7 * h / 8) - 1, w, 2)
    util.maskwin(main, mask)
    local old = term.redirect(main)
    parallel.waitForAny(function()
        sync(7.5)
        shell.run("parts/textscroller /assets/CraftOS-Normal-9.bdf 1 1.5 b Introducing the first ComputerCraft demo")
        sync(15.4)
        shell.run("parts/textscroller /assets/Michroma-36.bdf 512 4 f JackMacWindows by Created")
        sync(23.0)
        shell.run("parts/textscroller_sine /assets/PressStart2P-Regular-8.bdf 8192 1.25 f Original C64 music by Vans")
        sync(30.5)
    end, function()
        local dt = math.floor(1200 / w)
        while true do
            local img = {{}, {}, {}, {}, {}, {}}
            local t = (os.epoch "utc" - start) % 1000 * 48
            for x = 1, w * 2 do
                local s = math.min(math.floor(((chunk[t] or 0)*2 + 128) / 51) + 1, 6)
                img[1][x] = s == 1 and colors.gray or colors.black
                img[2][x] = s == 2 and colors.gray or colors.black
                img[3][x] = s == 3 and colors.gray or colors.black
                img[4][x] = s == 4 and colors.gray or colors.black
                img[5][x] = s == 5 and colors.gray or colors.black
                img[6][x] = s == 6 and colors.gray or colors.black
                t = t + dt
            end
            blt.drawBuffer(img, graph)
            sleep(0.05)
        end
    end)
    term.redirect(old)
    term.setPaletteColor(colors.black, 1, 1, 1)
    sleep(0.05)
    term.setPaletteColor(colors.black, 0, 0, 0)
    sleep(0.05)
    for i = 0, 15 do term.setPaletteColor(2^i, 1, 1, 1) end
    parallel.waitForAny(function()
        if h < 38 then shell.run("parts/herobrine.lua")
        elseif h < 56 then shell.run("parts/herobrine2x.lua")
        else shell.run("parts/herobrine3x.lua") end
    end, function()
        local col = {}
        for i = 0, 15 do col[i] = {term.getPaletteColor(2^i)} end
        sleep(0.05)
        for i = 9, 0, -1 do
            for j = 0, 15 do
                local r, g, b = col[j][1], col[j][2], col[j][3]
                term.setPaletteColor(2^j, r + (1 - r) * i/10, g + (1 - g) * i/10, b + (1 - b) * i/10)
            end
            sleep(0.05)
        end
        local br, bg, bb = term.nativePaletteColor(colors.black)
        sync(34.0)
        for i = 9, 0, -1 do
            for j = 0, 15 do
                local r, g, b = col[j][1], col[j][2], col[j][3]
                term.setPaletteColor(2^j, br + (r - br) * i/10, bg + (g - bg) * i/10, bb + (b - bb) * i/10)
            end
            sleep(0.05)
        end
    end)
    term.setBackgroundColor(colors.black)
    term.clear()
    for i = 0, 15 do term.setPaletteColor(2^i, term.nativePaletteColor(2^i)) end
    sync(34.5)
    shell.run("parts/texture_scroller_mask /assets/cct-64.bimg", 38.35 - (os.epoch "utc" - start) / 1000)
    sync(38.35)
    shell.run("parts/plasma", 42.2 - (os.epoch "utc" - start) / 1000)
    sync(42.2)
    shell.run("parts/textscroller /assets/CraftOS-Normal-9.bdf 2048 2 b Let's do a bit of 3D...")
    sync(46.0)
    shell.run("parts/80sparallax", 53.65 - (os.epoch "utc" - start) / 1000)
    sync(53.65)
    shell.run("parts/raycast", 61.35 - (os.epoch "utc" - start) / 1000)
    sync(61.35)
    shell.run("parts/physics", 69 - (os.epoch "utc" - start) / 1000)
    sync(69)
    shell.run("parts/sine", 76.65 - (os.epoch "utc" - start) / 1000)
    sync(76.65)
    parallel.waitForAll(
        function() shell.run("parts/tunnel3d", 92 - (os.epoch "utc" - start) / 1000) end,
        function() sync(84.3) term.setPaletteColor(colors.lightBlue, term.getPaletteColor(colors.red)) end
    )
    term.setPaletteColor(colors.lightBlue, term.nativePaletteColor(colors.lightBlue))
    sync(92)
    shell.run("parts/textscroller_circle /assets/CraftOS-Normal-9.bdf 2 1", 99.6 - (os.epoch "utc" - start) / 1000, "Pine3D")
    sync(99.6)
    shell.run("parts/mountains.lua", 107.3 - (os.epoch "utc" - start) / 1000)
    sync(107.3)
    shell.run("parts/c64spin.lua", 137.9 - (os.epoch "utc" - start) / 1000)
    sync(137.9)
    running = false
end)
for a = 0, 192000, 48000 do
    chunk = nextChunk()
    if not chunk then return end
    for i = 1, #chunk do chunk[i] = math.floor(chunk[i] * (240000 - i - a) / 240000) end
    os.pullEvent("speaker_audio_empty")
    speaker.playAudio(chunk, 3)
end
os.pullEvent("speaker_audio_empty")
for i = 0, 15 do term.setPaletteColor(2^i, term.nativePaletteColor(2^i)) end
term.setBackgroundColor(colors.black)
term.clear()
term.setCursorPos(1, 1)
term.setTextColor(colors.orange)
print("Thank you for experiencing this ONE OF A KIND demo for ComputerCraft !!")
term.setTextColor(colors.green)
print("I hope you enjoyed it :-)")
term.setTextColor(colors.yellow)
print("This was my first demo, and it was fun to throw together all my skills into one big program.")
term.setTextColor(colors.lightBlue)
print("Stay tuned for more demos in the future, possibly using C3D with textures and shaders?")
print()
term.setTextColor(colors.blue)
print("Herobrine demo (c) 2023 JackMacWindows")
print("Code licensed under GPLv2")
print("64x8_Logo-Editor (c) 1991 Pepijn Bruienne, all rights reserved")
print("Commodore 64 3D by Gabriele Falco 2015, CC BY-NC-SA")
print("Fonts licensed under OFL")
local t = term.current()
require("redrun").start(function()
    for _ = 1, 5 do
        t.setPaletteColor(colors.blue, term.nativePaletteColor(colors.black))
        sleep(0.5)
        t.setPaletteColor(colors.blue, term.nativePaletteColor(colors.blue))
        sleep(0.5)
    end
end)
os.queueEvent("HUP")
