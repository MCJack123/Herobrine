package.path = package.path .. ";/lib/?.lua"
local blt = require "betterblittle"
local time = tonumber(...)
local start = os.epoch "utc"
local w, h = term.getSize()
w, h = w * 2, h * 3
local e = select(2, math.frexp(math.max(w, h)))
local size = 2^e
local map = {{}}
map[1][1] = 0.00 --math.random()
map[1][size+1] = 0.25 --math.random()
map[size+1] = {}
map[size+1][1] = 0.50 --math.random()
map[size+1][size+1] = 0.75 --math.random()
local min, max = math.huge, -math.huge
for i = 0, e-1 do
    local exp = 2^(e-i)
    local hexp = exp / 2
    -- diamond
    for y = 1, size, exp do
        for x = 1, size, exp do
            local bx = x + exp
            local by = y + exp
            local c = (map[y][x] + map[y][bx] + map[by][x] + map[by][bx]) / 4 + (math.random() - 0.5) * 0.58^i
            map[y + hexp] = map[y + hexp] or {}
            map[y + hexp][x + hexp] = c
            min, max = math.min(min, c), math.max(max, c)
        end
    end
    -- square
    for y = 1, size + 1, hexp do
        for x = (y % exp == 1) and hexp+1 or 1, size + 1, exp do
            local r0 = map[y-hexp] or {}
            local r1 = map[y] or {}
            local r2 = map[y+hexp] or {}
            local c = ((r0[x] or 0) + (r2[x] or 0) + (r1[x-hexp] or 0) + (r1[x+hexp] or 0)) / 4 + (math.random() - 0.5) * 0.58^i
            map[y] = map[y] or {}
            map[y][x] = c
            min, max = math.min(min, c), math.max(max, c)
        end
    end
end
term.clear()
term.setCursorPos(1, 1)
for i = 0, 15 do term.setPaletteColor(2^i, i / 15, i / 15, i / 15) end
local range = 16 / (max - min)
-- [[
local buf = {}
for y = 1, size + 1 do
    local c = {}
    for x = 1, size + 1 do
        c[x] = 2^(math.max(math.min(math.floor((map[y][x] - min) * range), 15), 0))
    end
    buf[y] = c
end
blt.drawBuffer(buf, term.current())
--[=[]]
for y = 1, size + 1 do
    local c = ""
    for x = 1, size + 1 do
        c = c .. ("%x"):format(math.max(math.min(math.floor((map[y][x] - min) * range), 15), 0))
    end
    term.setCursorPos(1, y)
    term.blit((" "):rep(size + 1), ("0"):rep(size + 1), c)
end
--]=]
--time = time - (os.epoch "utc" - start) / 1000
local base, intensity = 0.2, 0.8
for i = 1, time * 20 do
    for j = 0, 15 do
        local xx = (i / 50 + j / 15) % 1
        -- [[
        local r = (math.max(math.abs(3.0*xx - 1.5) - 0.5, 0.0)) * intensity + base
        local g = (math.max(1 - math.abs(3.0*xx - 1), 0.0)) * intensity + base
        local b = (math.max(1 - math.abs(3.0*xx - 2), 0.0)) * intensity + base
        --[=[]]
        local r = math.max(1 - math.abs(6.0*xx - 1), 0.0)
        local g = math.max(1 - math.abs(6.0*xx - 3), 0.0)
        local b = math.max(1 - math.abs(6.0*xx - 5), 0.0)
        --]=]
        term.setPaletteColor(2^j, r, g, b)
    end
    sleep(0.05)
    if (os.epoch "utc" - start) / 1000 > time then break end
end
for i = 0, 15 do term.setPaletteColor(2^i, term.nativePaletteColor(2^i)) end
term.setBackgroundColor(colors.black)
term.setCursorPos(1, 1)
term.clear()