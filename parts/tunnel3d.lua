package.path = package.path .. ";/lib/?.lua"
local Pine3D = require "Pine3D"
local util = require "util"
local time = tonumber(...)
local start = os.epoch "utc"
local frame = Pine3D.newFrame()
local object = frame:newObject(util.loadCompressedModel("/models/tunnel.cob"), 0, -1, 0)
frame:setBackgroundColor(colors.black)
frame:setCamera(0, -1, -1, 180, 180, 0)
frame:setFoV(90)
frame:drawObjects({object})
frame:drawBuffer()
local pos = {-1, 0, -1}
local var = {"y", "x", "z"}
local look = {180, 180, 0}
local veca = vector.new()
for _ = 1, 3 do
    for i = 1, 6 do
        local s, ls = (i % 3 ~= 1 and -1 or 1), (i == 6 and 1 or -1)
        local lidx = i % 3 == 1 and 2 or 3
        local newlook = {look[1], look[2], look[3]}
        for j = 0, 14 do
            if os.epoch "utc" - start >= time * 1000 then
                term.setBackgroundColor(colors.black)
                term.setCursorPos(1, 1)
                term.clear()
                return
            end
            local t = math.pi / 2 * j/15 * s
            local newpos = {pos[1], pos[2] * math.cos(t) + pos[3] * math.sin(t), pos[3] * math.cos(t) - pos[2] * math.sin(t)}
            newlook[lidx] = look[lidx] + 90 * ls * math.sin(t)
            if i % 3 == 0 then newlook[1] = look[1] + (i == 3 and -90 or 90) * ls * math.sin(t) end
            veca[var[1]] = newpos[1]
            veca[var[2]] = newpos[2]
            veca[var[3]] = newpos[3]
            frame:setCamera(veca.x, veca.y, veca.z, newlook[1], newlook[2], newlook[3])
            frame:drawObjects({object})
            frame.buffer.blittleWindow.setPaletteColor(colors.lightBlue, term.getPaletteColor(colors.lightBlue))
            frame:drawBuffer()
            sleep(0.05)
        end
        pos = {pos[3] * s, -pos[2] * s, pos[1]}
        var = {var[2], var[3], var[1]}
        look[lidx] = (look[lidx] + 90 * ls * s) % 360
        if i % 3 == 0 then look[1] = (look[1] + (i == 3 and -90 or 90) * ls * s) % 360 end
        -- fix gimbal lock
        if i == 2 then
            look[1] = (look[1] - 90) % 360
            look[2] = (look[2] + 90) % 360
        elseif i == 5 then
            look[1] = (look[1] - 90) % 360
            look[2] = (look[2] - 90) % 360
        end
    end
    look = {(look[1] + 180) % 360, (look[2] + 180) % 360, (look[3] + 180) % 360}
end
term.setBackgroundColor(colors.black)
term.setCursorPos(1, 1)
term.clear()