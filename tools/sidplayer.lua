local M6502 = require "M6502"
local SID = require "sid"

term.clear()
term.setCursorPos(1, 1)
local win = window.create(term.current(), 38, 1, 14, 10)
win.clear()
local status = window.create(term.current(), 1, 1, 37, 19)
local oldterm = term.redirect(status)
local ok, err = pcall(function(...)
local mem = setmetatable({}, {__index = function() return 0 end})
local file = assert(fs.open(shell.resolve(...), "rb"))
local magicID = file.read(4)
if magicID ~= "RSID" and magicID ~= "PSID" then file.close() error("Not a SID file") end
local version, dataOffset, loadAddress, initAddress, playAddress, nsongs, defaultsong, speed, name, author, released = (">HHHHHHHIc32c32c32"):unpack(file.read(0x72))
if not name or not author or not released then file.close() error("Invalid SID file") end
name, author, released = name:gsub("%z+$", ""), author:gsub("%z+$", ""), released:gsub("%z+$", "")
local playerType, psidSpecific, ntsc, sidModel, secondSIDModel, thirdSIDModel, startPage, pageLength, secondSIDAddress, thirdSIDAddress = false, false, false, SID.chip_model.MOS6581, nil, nil, 0, 0, 0, 0
if version >= 2 or magicID == "RSID" then
    local flags
    flags, startPage, pageLength, secondSIDAddress, thirdSIDAddress = (">HBBBB"):unpack(file.read(6))
    playerType, psidSpecific, ntsc, sidModel = bit32.btest(flags, 0x0001), bit32.btest(flags, 0x0002), bit32.btest(flags, 0x0008), bit32.btest(flags, 0x0020) and SID.chip_model.MOS8580 or SID.chip_model.MOS6581
    if bit32.btest(flags, 0x00C0) then secondSIDModel = bit32.btest(flags, 0x0080) and SID.chip_model.MOS8580 or SID.chip_model.MOS6581
    else secondSIDModel = sidModel end
    if bit32.btest(flags, 0x0300) then secondSIDModel = bit32.btest(flags, 0x0200) and SID.chip_model.MOS8580 or SID.chip_model.MOS6581
    else thirdSIDModel = sidModel end
    secondSIDAddress, thirdSIDAddress = secondSIDAddress * 16, thirdSIDAddress * 16
end
file.seek("set", dataOffset)
if loadAddress == 0x0000 then loadAddress = ("<H"):unpack(file.read(2)) end
if initAddress == 0x0000 then initAddress = loadAddress end
if defaultsong == 0 then defaultsong = 1 end
print("Title:", name)
print("Author:", author)
print("Released:", released)
do
    local addr = loadAddress
    while true do
        local s = file.read()
        if not s then break end
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
if secondSIDAddress ~= 0 then
    sid[2] = SID:new()
    sid[2]:set_chip_model(secondSIDModel)
end
if thirdSIDAddress ~= 0 then
    sid[3] = SID:new()
    sid[3]:set_chip_model(thirdSIDModel)
end
function cpu:read(addr)
    if addr == 0x02A6 then return ntsc and 0 or 1 end
    if bit32.band(addr, 0xFC00) == 0xD400 then
        if bit32.band(addr, 0x0FE0) == secondSIDAddress then return sid[2]:read(bit32.band(addr, 0x001F))
        elseif bit32.band(addr, 0x0FE0) == thirdSIDAddress then return sid[3]:read(bit32.band(addr, 0x001F))
        else return sid[1]:read(bit32.band(addr, 0x001F)) end
    end
    return mem[addr]
end
function cpu:write(addr, val)
    if bit32.band(addr, 0xFC00) == 0xD400 then
        if bit32.band(addr, 0x0FE0) == secondSIDAddress then return sid[2]:write(bit32.band(addr, 0x001F), val)
        elseif bit32.band(addr, 0x0FE0) == thirdSIDAddress then return sid[3]:write(bit32.band(addr, 0x001F), val)
        else
            local channel = math.floor((addr - 0xD400) / 7)
            sid[1]:write(bit32.band(addr, 0x001F), val)
            if channel == 3 then
                win.setCursorPos(1, 7)
                win.write(("f %4d %X %X %X %X"):format(sid[1].filter.fc, sid[1].filter.vol, sid[1].filter.res, sid[1].filter.filt, sid[1].filter.hp_bp_lp + (sid[1].filter.voice3off and 8 or 0)))
            else
                win.setCursorPos(1, channel*2 + 1)
                win.write(("%d %5d %03X %02X"):format(channel, sid[1].voice[channel].wave.freq, sid[1].voice[channel].wave.pw, sid[1].voice[channel].control))
                win.setCursorPos(1, channel*2 + 2)
                win.write(("       %X %X %X %X"):format(sid[1].voice[channel].envelope.attack, sid[1].voice[channel].envelope.decay, sid[1].voice[channel].envelope.sustain, sid[1].voice[channel].envelope.release))
            end
        end
    else
        mem[addr] = val
    end
end

local song = tonumber(select(2, ...) or nil) or defaultsong
local speaker = assert(peripheral.find("speaker"), "Please attach a speaker.")
sid[1].extfilt:enable_filter(false)
print(("Initializing at %04X"):format(initAddress))
cpu.state.a = song
cpu:call(initAddress)
print(("Playing at %04X"):format(playAddress))
local n = 0
local data = {}
os.queueEvent("speaker_audio_empty", peripheral.getName(speaker))
while true do
    while #data < 48000 do
        cpu.state.pc = 0
        cpu:call(playAddress, 19705)
        sid[1]:clock(cpufreq / 50, data, #data + 1, 48000)
    end
    for i = 1, #data do data[i] = math.floor(data[i] / 256) end
    os.pullEvent("speaker_audio_empty")
    speaker.playAudio(data, 3)
    data = {}
    n = n + 1
end

end, ...)
term.redirect(oldterm)
if not ok then printError(err) end
