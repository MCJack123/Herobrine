package.path = package.path .. ";/lib/?.lua"
local Pine3D = require "Pine3D"
local util = require "util"
local time = tonumber(...)
local start = os.epoch "utc"
local frame = Pine3D.newFrame()
local text = "Greetings to: Xella#8655 123yeah_boi321#3385 Baastiplays#1915 Michiel#2082 Ocawesome101#5343 viluon#5360   SquidDev#8925 9551Dev#5787 AlexDevs#5164 Anavrins#4600 autist69420#2047 Banana_Prophet#6969 BlackDragon#8528 Compec#3355 EmmaKnijn#0043 Fatboychummy#4287 HydroNitrogen#9362 Impulse#7647 Jane#2187 Lemmmy#4600 migeyel#2107 minerobber#9690 Noodle#0406 NyoriE#8206 ShreksHellraiser#1951 SkyCrafter0#4576 VirtIO#1022 Wojbie#6085"
local palette = {
    {
      0.36470588235294,
      0.34509803921569,
      0.31764705882353,
    },
    {
      1,
      0,
      0,
    },
    {
      0.25882352941176,
      0.25882352941176,
      0.25882352941176,
    },
    {
      0.886275,
      0,
      0.101961,
    },
    {
      0.913725,
      0.368627,
      0.219608,
    },
    {
      1,
      0.8,
      0,
    },
    {
      0.341176,
      0.670588,
      0.152941,
    },
    {
      0,
      0.619608,
      0.878431,
    },
    {
      0.41960784313725,
      0.37647058823529,
      0.29411764705882,
    },
    {
      0.15294117647059,
      0.13725490196078,
      0.10980392156863,
    },
    {
      0.083506,
      0.083506,
      0.083506,
    },
    {
      0.75686274509804,
      0.70980392156863,
      0.63137254901961,
    },
    {
      0.6,
      0.56862745098039,
      0.47058823529412,
    },
    {
      0.55686274509804,
      0.50196078431373,
      0.39607843137255,
    },
    {
      0.55686274509804,
      0.50196078431373,
      0.39607843137255,
    },
    {
      0,
      0,
      0,
    },
  }
for i = 1, #palette do term.setPaletteColor(2^(i-1), table.unpack(palette[i])) end
local win = util.hscroller(window.create(term.current(), 1, 1, term.getSize(), 1))
win.setBackgroundColor(colors.black)
win.setTextColor(2048)
win.clear()
frame:setBackgroundColor(colors.black)
frame:setCamera(-15, 8, 0, 0, 0, -30)
frame:setFoV(60)
local obj = frame:newObject(util.loadCompressedModel("/models/c64.cob"), 0, 0, 0)
local w = math.floor((time - 2) * 40)
-- [[
for i = 1, w, 2 do
    obj:setRot(2 * math.pi * math.cos(2 * math.pi * i/200), 2 * math.pi * math.sin(2 * math.pi * i/310), 2 * math.pi * math.cos(2 * math.pi * i/420))
    frame:drawObjects({obj})
    frame:drawBuffer()
    win.hscroll(2, {{i > #text and "  " or text:sub(i, i + 1), "bb", "ff"}})
    sleep(0.05)
    if os.epoch "utc" - start >= (time - 2) * 1000 then w = i break end
end
for i = 1, 40 do
    local m = (40 - i) / 40
    for j = 1, #palette do frame.buffer.blittleWindow.setPaletteColor(2^(j-1), palette[j][1] * m, palette[j][2] * m, palette[j][3] * m) end
    obj:setRot(2 * math.pi * math.cos(2 * math.pi * (w+i*2)/200), 2 * math.pi * math.sin(2 * math.pi * (w+i*2)/310), 2 * math.pi * math.cos(2 * math.pi * (w+i*2)/420))
    frame:drawObjects({obj})
    frame:drawBuffer()
    sleep(0.05)
end
--[=[]]
for i = 1, w do
    obj:setRot(2 * math.pi * math.cos(2 * math.pi * i/100), 2 * math.pi * math.sin(2 * math.pi * i/150), 2 * math.pi * math.cos(2 * math.pi * i/200))
    frame:drawObjects({obj})
    frame:drawBuffer()
    win.hscroll(1, {{i > #text and " " or text:sub(i, i), "b", "f"}})
    sleep(0.05)
end
for i = 1, 40 do
    local m = (40 - i) / 40
    for j = 1, #palette do frame.buffer.blittleWindow.setPaletteColor(2^(j-1), palette[j][1] * m, palette[j][2] * m, palette[j][3] * m) end
    obj:setRot(2 * math.pi * math.cos(2 * math.pi * (w+i)/100), 2 * math.pi * math.sin(2 * math.pi * (w+i)/150), 2 * math.pi * math.cos(2 * math.pi * (w+i)/200))
    frame:drawObjects({obj})
    frame:drawBuffer()
    sleep(0.05)
end
--]=]
term.setBackgroundColor(colors.black)
term.clear()
term.setCursorPos(1, 1)
for i = 0, 15 do term.setPaletteColor(2^i, term.nativePaletteColor(2^i)) end