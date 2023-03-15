-- Usage: mkvfs <path to minified repo>
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
local file = assert(fs.open("loader.lua", "rb"))
local data = file.readAll()
file.close()
file = assert(fs.open("herobrine.lua", "wb"))
file.write("local disk=" .. textutils.serialize(pack(...), {compact = true}):gsub("\\\n", "\\n"))
file.write(data)
file.close()