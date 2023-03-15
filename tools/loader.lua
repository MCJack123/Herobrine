if "ä" ~= "\xE4" then
    local file = assert(fs.open(shell.getRunningProgram(), "rb"))
    local data = file.readAll()
    file.close()
    return assert(load(data, "@" .. shell.getRunningProgram(), nil, _ENV))()
end
local expect = require "cc.expect"

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

term.setBackgroundColor(colors.black)
term.setTextColor(colors.lime)
term.clear()
term.setCursorPos(1, 1)
write("PRE-LOAD INIT...")
term.setCursorBlink(true)
local ok, err = pcall(shell.run, "player")
_G.fs = fs
if not ok then printError(err) end
