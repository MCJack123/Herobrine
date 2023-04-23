if "ä" ~= "\xE4" then
    local file = assert(fs.open(shell.getRunningProgram(), "rb"))
    local data = file.readAll()
    file.close()
    return assert(load(data, "@" .. shell.getRunningProgram(), nil, _ENV))()
end
if #disk ~= size then error("File corrupted (expected " .. size .. ", got " .. #disk .. ")") end
local expect = require "cc.expect"

local rshift, lshift, band = bit32.rshift, bit32.lshift, bit32.band
local byte, char = string.byte, string.char
local concat, unpack = table.concat, unpack or table.unpack
local min = math.min

local ORDER = {17, 18, 19, 1, 9, 8, 10, 7, 11, 6, 12, 5, 13, 4, 14, 3, 15, 2, 16}
local NBT = {2, 3, 7}
local CNT  = {144, 112, 24, 8}
local DPT = {8, 9, 7, 8}
local STATIC_HUFFMAN = {[0] = 5, 261, 133, 389, 69, 325, 197, 453, 37, 293, 165, 421, 101, 357, 229, 485, 21, 277, 149, 405, 85, 341, 213, 469, 53, 309, 181, 437, 117, 373, 245, 501}
local STATIC_BITS = 5

local function flushBits(stream, int)
    stream.bits = rshift(stream.bits, int)
    stream.count = stream.count - int
end

local function peekBits(stream, int)
    local buffer, bits, count, position = stream.buffer, stream.bits, stream.count, stream.position
    while count < int do
        if position > #buffer then return nil end
        bits = bits + lshift(byte(buffer, position), count)
        position = position + 1
        count = count + 8
    end
    stream.bits = bits
    stream.position = position
    stream.count = count
    return band(bits, lshift(1, int) - 1)
end

local function getBits(stream, int)
    local result = peekBits(stream, int)
    stream.bits = rshift(stream.bits, int)
    stream.count = stream.count - int
    return result
end

local function getElement(stream, hufftable, int)
    local element = hufftable[peekBits(stream, int)]
    if not element then return nil end
    local length = band(element, 15)
    local result = rshift(element, 4)
    stream.bits = rshift(stream.bits, length)
    stream.count = stream.count - length
    return result
end

local function huffman(depths)
    local size = #depths
    local blocks, codes, hufftable = {[0] = 0}, {}, {}
    local bits, code = 1, 0
    for i = 1, size do
        local depth = depths[i]
        if depth > bits then
            bits = depth
        end
        blocks[depth] = (blocks[depth] or 0) + 1
    end
    for i = 1, bits do
        code = (code + (blocks[i - 1] or 0)) * 2
        codes[i] = code
    end
    for i = 1, size do
        local depth = depths[i]
        if depth > 0 then
            local element = (i - 1) * 16 + depth
            local rcode = 0
            for j = 1, depth do
                rcode = rcode + lshift(band(1, rshift(codes[depth], j - 1)), depth - j)
            end
            for j = 0, 2 ^ bits - 1, 2 ^ depth do
                hufftable[j + rcode] = element
            end
            codes[depth] = codes[depth] + 1
        end
    end
    return hufftable, bits
end

local function loop(output, stream, litTable, litBits, distTable, distBits)
    local index = #output + 1
    local lit
    repeat
        lit = getElement(stream, litTable, litBits)
        if not lit then return nil end
        if lit < 256 then
            output[index] = lit
            index = index + 1
        elseif lit > 256 then
            local bits, size, dist = 0, 3, 1
            if lit < 265 then
                size = size + lit - 257
            elseif lit < 285 then
                bits = rshift(lit - 261, 2)
                size = size + lshift(band(lit - 261, 3) + 4, bits)
            else
                size = 258

            end
            if bits > 0 then
                size = size + getBits(stream, bits)
            end
            local element = getElement(stream, distTable, distBits)
            if element < 4 then
                dist = dist + element
            else
                bits = rshift(element - 2, 1)
                dist = dist + lshift(band(element, 1) + 2, bits) + getBits(stream, bits)
            end
            local position = index - dist
            repeat
                output[index] = output[position] or 0
                index = index + 1
                position = position + 1
                size = size - 1
            until size == 0
        end
    until lit == 256
end

local function dynamic(output, stream)
    local n = getBits(stream, 5)
    if not n then return nil end
    local lit, dist, length = 257 + n, 1 + getBits(stream, 5), 4 + getBits(stream, 4)
    local depths = {}
    for i = 1, length do
        depths[ORDER[i]] = getBits(stream, 3)
    end
    for i = length + 1, 19 do
        depths[ORDER[i]] = 0
    end
    local lengthTable, lengthBits = huffman(depths)
    local i = 1
    local total = lit + dist + 1
    repeat
        local element = getElement(stream, lengthTable, lengthBits)
        if element < 16 then
            depths[i] = element
            i = i + 1
        elseif element < 19 then
            local int = NBT[element  - 15]
            local count = 0
            local num = 3 + getBits(stream, int)
            if element == 16 then
                count = depths[i - 1]
            elseif element == 18 then
                num = num + 8
            end
            for _ = 1, num do
                depths[i] = count
                i = i + 1
            end
        end
    until i == total
    local litDepths, distDepths = {}, {}
    for j = 1, lit do
        litDepths[j] = depths[j]
    end
    for j = lit + 1, #depths do
        distDepths[#distDepths + 1] = depths[j]
    end
    local litTable, litBits = huffman(litDepths)
    local distTable, distBits = huffman(distDepths)
    loop(output, stream, litTable, litBits, distTable, distBits)
end

local function static(output, stream)
    local depths = {}
    for i = 1, 4 do
        local depth = DPT[i]
        for _ = 1, CNT[i] do
            depths[#depths + 1] = depth
        end
    end
    local litTable, litBits = huffman(depths)
    loop(output, stream, litTable, litBits, STATIC_HUFFMAN, STATIC_BITS)
end

local function uncompressed(output, stream)
    flushBits(stream, band(stream.count, 7))
    local length = getBits(stream, 16); getBits(stream, 16)
    if not length then return nil end
    local buffer, position = stream.buffer, stream.position
    for i = position, position + length - 1 do
        output[#output + 1] = byte(buffer, i, i)
    end
    stream.position = position + length
end

local function inflate(data)
    local self = {buffer = data, position = 1, bits = 0, count = 0}
    local output, buffer = {}, {}
    local last, typ
    repeat
        last, typ = getBits(self, 1), getBits(self, 2)
        if not last or not typ then break end
        typ = typ == 0 and uncompressed(output, self) or typ == 1 and static(output, self) or typ == 2 and dynamic(output, self)
    until last == 1
    local size = #output
    for i = 1, size, 4096 do
        buffer[#buffer + 1] = char(unpack(output, i, min(i + 4095, size)))
    end
    return concat(buffer)
end

local function getPath(tab, path)
    for p in fs.combine(path):gmatch("[^/]+") do
        tab = tab[p]
        if tab == nil then return nil end
    end
    return tab
end

local function aux_find(parts, t)
    if #parts == 0 then return type(t) == "table" and "" or t elseif type(t) ~= "table" then return nil end
    local parts2 = {}
    for i,v in ipairs(parts) do parts2[i] = v end
    local name = table.remove(parts2, 1)
    local retval = {}
    if t then for k, v in pairs(t) do if k:match("^" .. name:gsub("([%%%.])", "%%%1"):gsub("%*", "%.%*") .. "$") then retval[k] = aux_find(parts2, v) end end end
    return retval
end

local function combineKeys(t, prefix)
    prefix = prefix or ""
    if t == nil then return {} end
    local retval = {}
    for k,v in pairs(t) do
        if type(v) == "string" then table.insert(retval, prefix .. k)
        else for _,w in ipairs(combineKeys(v, prefix .. k .. "/")) do table.insert(retval, w) end end
    end
    return retval
end

term.setBackgroundColor(colors.black)
term.setTextColor(colors.lime)
term.clear()
term.setCursorPos(1, 1)
write("PRE-LOAD INIT...")
term.setCursorBlink(true)
local data = inflate(disk)
disk = textutils.unserialize(data)
sleep(0)

local fs = fs
_G.fs = {
    list = function(path)
        expect(1, path, "string")
        if path:match "^/?rom" then return fs.list(path) end
        local tab = getPath(disk, path)
        if type(tab) ~= "table" then error(path .. ": Not a directory", 2) end
        local retval = {}
        for k in pairs(tab) do retval[#retval+1] = k end
        local parts = {}
        for p in fs.combine(path):gmatch("[^/]+") do parts[#parts+1] = p end
        table.sort(retval)
        return retval
    end,
    exists = function(path)
        expect(1, path, "string")
        if path:match "^/?rom" then return fs.exists(path) end
        return getPath(disk, path) ~= nil
    end,
    isDir = function(path)
        expect(1, path, "string")
        if path:match "^/?rom" then return fs.isDir(path) end
        local tab = getPath(disk, path)
        return type(tab) == "table"
    end,
    isReadOnly = function(path)
        expect(1, path, "string")
        return true
    end,
    getName = fs.getName,
    getDrive = function(path)
        expect(1, path, "string")
        return "hdd"
    end,
    getSize = function(path)
        expect(1, path, "string")
        if path:match "^/?rom" then return fs.getSize(path) end
        local tab = getPath(disk, path)
        if tab == nil then error(path .. ": No such file") end
        if type(tab) == "table" then return 0
        else return #tab end
    end,
    getFreeSpace = function(path)
        expect(1, path, "string")
        return 0
    end,
    makeDir = function(path)
        error("Read only filesystem", 2)
    end,
    move = function()
        error("Read only filesystem", 2)
    end,
    copy = function()
        error("Read only filesystem", 2)
    end,
    delete = function()
        error("Read only filesystem", 2)
    end,
    combine = fs.combine,
    open = function(path, mode)
        expect(1, path, "string")
        expect(2, mode, "string")
        if path:match "^/?rom" then return fs.open(path, mode) end
        if mode == "r" then
            local tab = getPath(disk, path)
            if type(tab) ~= "string" then return nil, "No such file" end
            local oldtab = tab
            tab = ""
            for _, c in utf8.codes(oldtab) do tab = tab .. (c > 255 and "?" or string.char(c)) end
            tab = tab:gsub("\r\n", "\n")
            local pos = 1
            local closed = false
            return {
                readLine = function(withTrailing)
                    if closed then error("file is already closed", 2) end
                    if pos > #tab then return end
                    local str, endPos = tab:match(withTrailing and "([^\n]*\n?)()" or "([^\n]*)\n?()", pos)
                    pos = str and endPos or #tab + 1
                    return str
                end,
                readAll = function()
                    if closed then error("file is already closed", 2) end
                    if #tab == 0 and pos == 1 then
                        pos = 2
                        return ""
                    end
                    if pos > #tab then return end
                    local oldPos = pos
                    pos = #tab + 1
                    return tab:sub(oldPos)
                end,
                read = function(count)
                    if closed then error("file is already closed", 2) end
                    if pos > #tab then return end
                    expect(1, count, "number", "nil")
                    count = count or 1
                    local oldPos = pos
                    pos = pos + count
                    return tab:sub(oldPos, pos - 1)
                end,
                close = function()
                    if closed then error("file is already closed", 2) end
                    closed = true
                end
            }
        elseif mode == "w" or mode == "a" then
            return nil, "Read only filesystem"
        elseif mode == "rb" then
            local tab = getPath(disk, path)
            if type(tab) ~= "string" then return nil, "No such file" end
            local pos = 1
            local closed = false
            return {
                readLine = function(withTrailing)
                    if closed then error("file is already closed", 2) end
                    if pos > #tab then return end
                    local str, endPos = tab:match(withTrailing and "([^\n]*\n?)()" or "([^\n]*)\n?()", pos)
                    pos = str and endPos or #tab + 1
                    return str
                end,
                readAll = function()
                    if closed then error("file is already closed", 2) end
                    if #tab == 0 and pos == 1 then
                        pos = 2
                        return ""
                    end
                    if pos > #tab then return end
                    local oldPos = pos
                    pos = #tab + 1
                    return tab:sub(oldPos)
                end,
                read = function(count)
                    expect(1, count, "number", "nil")
                    if closed then error("file is already closed", 2) end
                    if pos > #tab then return end
                    if count == nil then
                        pos = pos + 1
                        return tab:byte(pos - 1)
                    else
                        local oldPos = pos
                        pos = pos + count
                        return tab:sub(oldPos, pos - 1)
                    end
                end,
                close = function()
                    if closed then error("file is already closed", 2) end
                    closed = true
                end,
                seek = function(whence, offset)
                    if closed then error("file is already closed", 2) end
                    expect(1, whence, "string", "nil")
                    expect(2, offset, "number", "nil")
                    whence = whence or "cur"
                    offset = offset or 0
                    if whence == "set" then pos = offset + 1
                    elseif whence == "cur" then pos = pos + offset
                    elseif whence == "end" then pos = #tab - offset
                    else error("bad argument #1 (invalid option " .. whence .. ")", 2) end
                    return pos
                end
            }
        elseif mode == "wb" or mode == "ab" then
            return nil, "Read only filesystem"
        else return nil, "Invalid mode" end
    end,
    find = function(wildcard)
        expect(1, wildcard, "string")
        local parts = {}
        for p in wildcard:gmatch("[^/]+") do parts[#parts+1] = p end
        local retval = {}
        for _,v in ipairs(combineKeys(aux_find(parts, disk))) do table.insert(retval, v) end
        table.sort(retval)
        return retval
    end,
    getDir = fs.getDir,
    attributes = function(path)
        expect(1, path, "string")
        if path:match "^/?rom" then return fs.attributes(path) end
        local tab = getPath(disk, path)
        return {
            size = type(tab) == "table" and 0 or #tab,
            isDir = type(tab) == "table",
            isReadOnly = false,
            created = 0,
            modified = 0
        }
    end,
    getCapacity = function(path)
        expect(1, path, "string")
        return 1000000
    end
}

local ok, err = pcall(shell.run, "player")
_G.fs = fs
if not ok then printError(err) end
