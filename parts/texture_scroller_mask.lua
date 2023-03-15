package.path = package.path .. ";/lib/?.lua"
local util = require "util"
local path, time = ...
time = tonumber(time)
local start = os.epoch "utc"
local file = assert(fs.open(shell.resolve(path), "rb"))
local img = textutils.unserialize(file.readAll())
file.close()
local imgw, imgh = #img[1][1][1], #img[1]
local w, h = term.getSize()
local win = util.hscroller(window.create(term.current(), 1, 1, w, h))
local mask = window.create(term.current(), 1, 1, w, h)
local circle = {
    {
        "          ",
        "ffffffffff",
        "ffffffffff"
    },
    {
        "  \x87\x81\0\0\x82\x8B  ",
        "ffff\0\0ffff",
        "ff\0\0\0\0\0\0ff"
    },
    {
        " \x85\0\0\0\0\0\0\x8A ",
        "ff\0\0\0\0\0\0ff",
        "f\0\0\0\0\0\0\0\0f"
    },
    {
        " \0\0\0\0\0\0\0\0 ",
        "f\0\0\0\0\0\0\0\0f",
        "f\0\0\0\0\0\0\0\0f"
    },
    {
        " \0\0\0\0\0\0\0\0 ",
        "f\0\0\0\0\0\0\0\0f",
        "f\0\0\0\0\0\0\0\0f"
    },
    {
        " \x8A\0\0\0\0\0\0\x85 ",
        "f\1\0\0\0\0\0\0\1f",
        "ff\0\0\0\0\0\0ff"
    },
    {
        "  \x82\x8B\x8F\x8F\x87\x81  ",
        "ff\1\1\1\1\1\1ff",
        "ffffffffff"
    },
    {
        "          ",
        "ffffffffff",
        "ffffffffff"
    }
}
for i = 1, #circle do
    local ii = (i + math.floor(#circle / 2) - 1) % #circle + 1
    circle[i][1] = circle[i][1] .. circle[ii][1]:sub(1, 10)
    circle[i][2] = circle[i][2] .. circle[ii][2]:sub(1, 10)
    circle[i][3] = circle[i][3] .. circle[ii][3]:sub(1, 10)
end
local circlerep = math.ceil(w / 20)
for y = 1, h do
    local line = circle[(y - 1) % #circle + 1]
    mask.setCursorPos(1, y)
    mask.blit(line[1]:rep(circlerep), line[2]:rep(circlerep), line[3]:rep(circlerep))
end
term.setCursorPos(1, 1)
util.maskwin(win, mask)
local rep = math.ceil(w / imgw)
win.setVisible(false)
for y = 1, h do
    win.setCursorPos(1, y)
    local ny = (y - 1) % imgh + 1
    win.blit(img[1][ny][1]:rep(rep), img[1][ny][2]:rep(rep), img[1][ny][3]:rep(rep))
end
for i = 0, #img[1].palette do win.setPaletteColor(2^i, table.unpack(img[1].palette[i])) end
win.setVisible(true)
local x, y = 1, 1
sleep(0.05)
time = time - (os.epoch "utc" - start) / 1000
for _ = 1, time * 10 do
    local rs = {}
    local nx = (x+w-1)%imgw+1
    for ny = 1, h do
        local l = img[1][(ny+y-2) % imgh + 1]
        rs[ny] = {l[1]:sub(nx, nx), l[2]:sub(nx, nx), l[3]:sub(nx, nx)}
    end
    win.setVisible(false)
    win.hscroll(1, rs)
    win.scroll(1)
    win.setCursorPos(1, h)
    local ny = (y+h-1)%imgh+1
    x, y = x % imgw + 1, y % imgh + 1
    win.blit(img[1][ny][1]:sub(x) .. img[1][ny][1]:rep(rep), img[1][ny][2]:sub(x) .. img[1][ny][2]:rep(rep), img[1][ny][3]:sub(x) .. img[1][ny][3]:rep(rep))
    win.setVisible(true)
    sleep(0.1)
end
term.setBackgroundColor(colors.black)
term.clear()
term.setCursorPos(1, 1)
for i = 0, 15 do term.setPaletteColor(2^i, term.nativePaletteColor(2^i)) end