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
local chars = {}
local maxx = 0
local x, y = 1, 1
local scale = math.max(math.floor(h * 1.5 / font.size.px), 1)
for c in string.gmatch(text, ".") do
    local fc = font.chars[c]
    local img = {x = math.floor((x + fc.bounds.x) * scale / 2), y = math.floor((y - fc.bounds.y - fc.bounds.height + ascent - descent) * scale / 3)}
    chars[#chars+1] = img
    for py = 1, fc.bounds.height do
        for px = 1, fc.bounds.width do
            if fc.bitmap[py][px] then
                for yy = 1, scale do
                    img[(py-1)*scale+yy] = img[(py-1)*scale+yy] or {}
                    for xx = 1, scale do
                        img[(py-1)*scale+yy][(px-1)*scale+xx] = color
                    end
                end
            else
                for yy = 1, scale do
                    img[(py-1)*scale+yy] = img[(py-1)*scale+yy] or {}
                    for xx = 1, scale do
                        img[(py-1)*scale+yy][(px-1)*scale+xx] = colors.black
                    end
                end
            end
            maxx = math.max(maxx, (img.x*2+px*scale))
        end
    end
    img.win = window.create(term.current(), img.x, img.y, math.ceil(fc.bounds.width * scale / 2), math.ceil(fc.bounds.height * scale / 3), false)
    blt.drawBuffer(img, img.win)
    x = x + fc.device_width.x + 1
end
local ok, err = pcall(function()
for i = 1, maxx / 2 + w, speed*scale do
    term.clear()
    for _, win in ipairs(chars) do
        win.win.reposition(win.x + w - i, math.floor(win.y + h / 2 - h * (math.sin(2 * math.pi * (win.x + w - i) / (w * 0.75)) + 1) / 4))
        win.win.setVisible(true)
    end
    sleep(0.05)
end
end)
term.setCursorPos(1, 1)
term.clear()
if not ok then printError(err) end
