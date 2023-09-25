local Pine3D = require "Pine3D"
local util = {}

local hsidx = 1
local k1, k2, k3
if _HOST >= "ComputerCraft 1.106" then k1, k2, k3 = 1, 2, 3
else k1, k2, k3 = "text", "textColor", "backgroundColor" end
function util.hscroller(win)
    local k, tLines = debug.getupvalue(win.getLine, hsidx)
    while k ~= "tLines" do
        hsidx = hsidx + 1
        k, tLines = debug.getupvalue(win.getLine, hsidx)
    end
    function win.hscroll(cols, rs)
        cols = math.floor(cols)
        if not rs then
            local fg, bg = win.getTextColor(), win.getBackgroundColor()
            local a, b, c = (" "):rep(math.abs(cols)), ("%x"):format(select(2, math.frexp(fg))+1):rep(math.abs(cols)), ("%x"):format(select(2, math.frexp(bg))+1):rep(math.abs(cols))
            rs = {}
            for y = 1, #tLines do rs[y] = {a, b, c} end
        end
        if cols >= 1 then
            for y = 1, #tLines do
                tLines[y][k1] = tLines[y][k1]:sub(cols + 1) .. rs[y][1]
                tLines[y][k2] = tLines[y][k2]:sub(cols + 1) .. rs[y][2]
                tLines[y][k3] = tLines[y][k3]:sub(cols + 1) .. rs[y][3]
            end
            win.redraw()
        elseif cols <= -1 then
            for y = 1, #tLines do
                tLines[y][k1] = rs[y][1] .. tLines[y][k1]:sub(1, cols - 1)
                tLines[y][k2] = rs[y][2] .. tLines[y][k2]:sub(1, cols - 1)
                tLines[y][k3] = rs[y][3] .. tLines[y][k3]:sub(1, cols - 1)
            end
            win.redraw()
        end
    end
    local oldscroll = win.scroll
    function win.scroll(...)
        oldscroll(...)
        k, tLines = debug.getupvalue(win.getLine, hsidx)
    end
    function win.setAllLines(img)
        for y = 1, #img do tLines[y] = img[y] end
    end
    return win
end

local parentidx, internalBlitidx, redrawidx, redrawLine_internalBlitidx, redrawLine_redrawidx, redrawLine_clearLineidx = 1, 1, 1, 1, 1, 1
function util.maskwin(win, mask)
    local k, tLinesMask, tLinesWin, parent, internalBlit, redraw
    k, tLinesMask = debug.getupvalue(mask.getLine, hsidx)
    while k ~= "tLines" do
        hsidx = hsidx + 1
        k, tLinesMask = debug.getupvalue(mask.getLine, hsidx)
    end
    k, tLinesWin = debug.getupvalue(win.getLine, hsidx)
    k, parent = debug.getupvalue(mask.reposition, parentidx)
    while k ~= "parent" do
        parentidx = parentidx + 1
        k, parent = debug.getupvalue(mask.reposition, parentidx)
    end
    local nX, nY = mask.getPosition()

    local function redrawLine(n)
        local tLine = tLinesMask[n]
        local tLineWin = tLinesWin[n]
        parent.setCursorPos(nX, nY + n - 1)
        parent.blit(
            tLine[k1]:gsub("()%z+()", function(x, y) return tLineWin[k1]:sub(x, y-1) end),
            tLine[k2]:gsub("()%z+()", function(x, y) return tLineWin[k2]:sub(x, y-1) end)
                :gsub("()\1+()", function(x, y) return tLineWin[k3]:sub(x, y-1) end),
            tLine[k3]:gsub("()%z+()", function(x, y) return tLineWin[k3]:sub(x, y-1) end))
    end
    -- Now we go fishing for all redrawLine upvalues
    k, internalBlit = debug.getupvalue(mask.blit, internalBlitidx)
    while k ~= "internalBlit" do
        internalBlitidx = internalBlitidx + 1
        k, internalBlit = debug.getupvalue(mask.blit, internalBlitidx)
    end
    k = debug.getupvalue(internalBlit, redrawLine_internalBlitidx)
    while k ~= "redrawLine" do
        redrawLine_internalBlitidx = redrawLine_internalBlitidx + 1
        k = debug.getupvalue(internalBlit, redrawLine_internalBlitidx)
    end
    debug.setupvalue(internalBlit, redrawLine_internalBlitidx, redrawLine)
    k, internalBlit = debug.getupvalue(win.blit, internalBlitidx)
    debug.setupvalue(internalBlit, redrawLine_internalBlitidx, redrawLine)

    k, redraw = debug.getupvalue(mask.clear, redrawidx)
    while k ~= "redraw" do
        redrawidx = redrawidx + 1
        k, redraw = debug.getupvalue(mask.clear, redrawidx)
    end
    k = debug.getupvalue(redraw, redrawLine_redrawidx)
    while k ~= "redrawLine" do
        redrawLine_redrawidx = redrawLine_redrawidx + 1
        k = debug.getupvalue(redraw, redrawLine_redrawidx)
    end
    debug.setupvalue(redraw, redrawLine_redrawidx, redrawLine)
    k, redraw = debug.getupvalue(win.clear, redrawidx)

    k = debug.getupvalue(mask.clearLine, redrawLine_clearLineidx)
    while k ~= "redrawLine" do
        redrawLine_clearLineidx = redrawLine_clearLineidx + 1
        k = debug.getupvalue(mask.clearLine, redrawLine_clearLineidx)
    end
    debug.setupvalue(mask.clearLine, redrawLine_clearLineidx, redrawLine)
    debug.setupvalue(win.clearLine, redrawLine_clearLineidx, redrawLine)

    local oldscrollmask = mask.scroll
    function mask.scroll(...)
        oldscrollmask(...)
        k, tLinesMask = debug.getupvalue(mask.getLine, hsidx)
    end
    local oldscrollwin = win.scroll
    function win.scroll(...)
        oldscrollwin(...)
        k, tLinesWin = debug.getupvalue(win.getLine, hsidx)
    end
end

function util.loadCompressedModel(path)
    local file = assert(fs.open(path, "rb"))
    local npolys = ("<I4"):unpack(file.read(4))
    local t = {}
    for i = 1, npolys do
        local o = {}
        t[i] = o
        o.c, o.x1, o.y1, o.z1, o.x2, o.y2, o.z2, o.x3, o.y3, o.z3 = ("<Bfffffffff"):unpack(file.read(37))
        o.forceRender = bit32.btest(o.c, 0x80)
        o.c = 2^bit32.band(o.c, 0x0F)
    end
    file.close()
    if not Pine3D.transforms then
        local idx = 1
        local k, transforms = debug.getupvalue(Pine3D.loadModel, idx)
        while k ~= "transforms" do
            idx = idx + 1
            k, transforms = debug.getupvalue(Pine3D.loadModel, idx)
        end
        Pine3D.transforms = transforms
    end
    for name, func in pairs(Pine3D.transforms) do
        t[name] = func
    end
    return t
end

return util