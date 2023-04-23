local LibDeflate = require "LibDeflate"
local function pack(path)
    if fs.isDir(path) then
        local t = {}
        for _, k in ipairs(fs.list(path)) do t[k] = pack(fs.combine(path, k)) end
        return t
    else
        local file = assert(fs.open(path, "rb"))
        local data = file.readAll()
        file.close()
        return data
    end
end
local file = assert(fs.open("loader.min.lua", "rb"))
local data = file.readAll()
file.close()
local orig = textutils.serialize(pack("dist/min"), {compact = true}):gsub("\\\n", "\\n")
local cmp = LibDeflate:CompressDeflate(orig, {level = 9})
file = assert(fs.open("herobrine.lua", "wb"))
--file.write("local disk,size=[===[" .. cmp .. "]===]," .. #cmp .. " ")
file.write("local disk,size='" .. cmp:gsub("\\", "\\\\"):gsub("\n", "\\n"):gsub("\r", "\\r"):gsub("%z", "\\000"):gsub("'", "\\'") .. "'," .. #cmp .. " ")
--file.write("local disk='" .. LibDeflate:CompressDeflate(textutils.serialize(pack("dist/min"), {compact = true}):gsub("\\\n", "\\n"), {}):gsub(".", function(c) return ("\\x%02X"):format(c:byte()) end) .. "'")
file.write(data)
file.close()