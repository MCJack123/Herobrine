package.path = package.path .. ";/lib/?.lua"
local blt = require "betterblittle"
local util = require "util"
local time = tonumber(...)
local start = os.epoch "utc"
local tree = {
    {
        "\x8F\x8B\x8B\x88\x90",
        "\1a\1\0\1",
        "a\0aa\0"
    },
    {
        "\x82\x84\x90\x92\x93",
        "a\0\0\0a",
        "\0aaa\0"
    },
    {
        "\x82\x81\0\x95\x81",
        "aa\0aa",
        "\0\0\0\0\0"
    },
    {
        "\0\0\0\x95\0",
        "\0\0\0\1\0",
        "\0\0\0a\0"
    }
}
local w, h = term.getSize()
local win = window.create(term.current(), 1, 1, w, h)
local mask = window.create(term.current(), 1, 1, w, h)
util.hscroller(mask)
util.maskwin(win, mask)
local rs = {}
do
    local hh = math.floor(h / 2)
    local l = ("\0"):rep(w)
    for y = 1, h do
        mask.setCursorPos(1, y)
        mask.blit(l, l, l)
        rs[y] = {'\0', '\0', '\0'}
    end
    local x = math.max(math.floor(w / 8), 3)
    while x < w do
        mask.setCursorPos(x, hh-1)
        mask.blit(table.unpack(tree[1]))
        mask.setCursorPos(x, hh-0)
        mask.blit(table.unpack(tree[2]))
        mask.setCursorPos(x, hh+1)
        mask.blit(table.unpack(tree[3]))
        mask.setCursorPos(x, hh+2)
        mask.blit(table.unpack(tree[4]))
        x = x + math.random(math.floor(w / 8), math.floor(w / 4))
    end
end
w, h = w * 2, h * 3
term.clear()
local img = {}
local hw, hh = math.floor(w / 2), math.ceil(h / 2)
local bg, fg, sun1, sun2 = colors.black, colors.magenta, colors.orange, colors.red
for y = 1, h do img[y] = {} for x = 1, w do img[y][x] = bg end end
local r = hh - 7
local step = math.pi / (4 * r)
local miny = math.huge
for theta = 0, math.pi * 2, step do
    local px, py = r * math.cos(theta), r * math.sin(theta)
    miny = math.min(miny, hh+py)
    img[math.floor(hh+py)][math.floor(hw+px)] = py > -4 and sun2 or sun1
end
for y = miny + 1, h do
    local d = nil
    local a = false
    for x = 1, w do
        if img[y][x] ~= bg then if d and not a then break else d, a = img[y][x], true end
        elseif d then img[y][x], a = d, false end
    end
end
do
    local y = 7
    local yper = r * 0.5
    while y < hh + 3 and yper >= 0.2 do
        local yy = math.floor(y)
        for x = 1, w do img[yy][x] = bg end
        y = y + yper
        yper = yper * 0.53
    end
end
--time = time - (os.epoch "utc" - start) / 1000
for i = 1, time * 20 do
    --start = os.epoch "utc"
    local d, dx = 2, 1
    for y = hh + 3, h do
        if d == dx then
            for x = 1, w do img[y][x] = fg end
            d, dx = d + 1, 1
        else
            local dist = math.max(math.floor(math.tan(math.pi / 6) * (y - hh)), 1)
            local off = math.floor(dist * i/10)
            local dw = math.ceil(w / dist) * dist
            for x = 0, w, dist do
                img[y][(hw + x + off - 1) % dw + 1] = fg
                img[y][(hw - x + off - 1) % dw + 1] = fg
                for n = hw + x + 1, x + dist - 1 do img[y][(n + off - 1) % dw + 1] = bg end
                for n = hw - x - 1, hw - x - dist + 1, -1 do img[y][(n + off - 1) % dw + 1] = bg end
            end
            dx = dx + 1
        end
    end
    blt.drawBuffer(img, win)
    if i % 8 == 0 then mask.hscroll(-1, rs) end
    sleep(0.05)
    if (os.epoch "utc" - start) / 1000 > time then break end
end
term.setBackgroundColor(colors.black)
term.setCursorPos(1, 1)
term.clear()