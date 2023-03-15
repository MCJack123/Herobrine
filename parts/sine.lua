package.path = package.path .. ";/lib/?.lua"
local Pine3D = require "Pine3D"
local time = tonumber(...)
local start = os.epoch "utc"

local frame = Pine3D.newFrame()
local objects = {{color = colors.red}, {color = colors.blue}, {color = colors.orange}}
for n = 0, 2 do
    for i = 1, 50+n*15 do
        objects[n+1][i] = frame:newObject(Pine3D.models:sphere{color = objects[n+1].color, res = 5-n}, n*5, 0, i-n)
    end
end

frame:setCamera(-10, 5, 5, 0, 30, -15)
frame:setFoV(90)
frame:setBackgroundColor(colors.black)
--time = time - (os.epoch "utc" - start) / 1000
for i = 1, time*20 do
    --start = os.epoch "utc"
    for n = #objects, 1, -1 do
        for _, v in ipairs(objects[n]) do
            v[2] = math.sin(2 * math.pi * (v[3] + (i+n*1)/2) / (8+n*5)) * 2
        end
        frame:drawObjects(objects[n])
    end
    frame:drawBuffer()
    sleep(0.05)
    if (os.epoch "utc" - start) / 1000 > time then break end
end
term.setBackgroundColor(colors.black)
term.setCursorPos(1, 1)
term.clear()