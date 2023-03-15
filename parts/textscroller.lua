package.path = package.path .. ";/lib/?.lua"
local readBDFFont = require "bdf"
local blt = require "betterblittle"
local args = {...}
local fontname = table.remove(args, 1)
local color = tonumber(table.remove(args, 1))
local speed = tonumber(table.remove(args, 1))
local forward = table.remove(args, 1) == "f"
local text = table.concat(args, " ")
local file = assert(fs.open(fontname, "r"))
local font = readBDFFont(file.readAll())
file.close()
local direction = font.slant ~= "R"
local overall = {lbearing = 0, rbearing = 0, width = 0, ascent = 0, descent = 0}
for c in string.gmatch(text, ".") do
    local fch = font.chars[c]
    overall.ascent = math.floor(math.max(overall.ascent, fch.bounds.y + fch.bounds.height))
    overall.descent = math.floor(math.min(overall.descent, fch.bounds.y))
    overall.lbearing = math.floor(math.min(overall.lbearing, fch.bounds.x + overall.width))
    overall.rbearing = math.floor(math.max(overall.rbearing, fch.bounds.x + fch.bounds.width + overall.width))
    overall.width = math.floor(overall.width + fch.device_width.x)
end
local err, ascent, descent = direction, overall.ascent, overall.descent
local w, h = term.getSize()
local img = {}
local maxx = 0
local scale = math.floor(h * 3 / font.size.px)
scale = math.floor((h * 3 + font.bounds.y * scale) / font.size.px)
local x, y = 1, math.ceil((h * 3 - font.size.px*scale) / 6) + math.floor(font.bounds.y*scale/3)
for c in string.gmatch(text, ".") do
    local fc = font.chars[c]
    for py = 1, fc.bounds.height do for px = 1, fc.bounds.width do if fc.bitmap[py][px] then
        local ax, ay = x + px + fc.bounds.x, y + py - fc.bounds.y - fc.bounds.height + ascent - descent
        for yy = 1, scale do
            img[(ay-1)*scale+yy] = img[(ay-1)*scale+yy] or {}
            for xx = 1, scale do
                img[(ay-1)*scale+yy][(ax-1)*scale+xx] = color
            end
        end
        maxx = math.max(maxx, ax*scale)
    end end end
    x = x + fc.device_width.x + 1
end
for y = 1, math.max(h * 3, table.maxn(img)) do local r = img[y] or {} img[y] = r for x = 1, maxx do r[x] = r[x] or colors.black end end
local win = window.create(term.current(), w, 1, maxx, h)
term.clear()
local ok, err = pcall(function()
blt.drawBuffer(img, win)
if forward then for i = maxx / 2 + w, 1, -speed * scale do term.clear() win.reposition(w - i, 1) sleep(0.05) end
else for i = 1, maxx / 2 + w, speed * scale do win.reposition(w - i, 1) sleep(0.05) end end
end)
term.setCursorPos(1, 1)
term.clear()
if not ok then printError(err) end