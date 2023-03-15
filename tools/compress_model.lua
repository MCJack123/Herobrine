local file = assert(fs.open("models/" .. ..., "rb"))
local data = textutils.unserialize(file.readAll())
file.close()
local out = assert(fs.open("models/" .. ... .. ".cob", "wb"))
out.write(("<I4"):pack(#data))
for i, v in ipairs(data) do out.write(("<Bfffffffff"):pack(select(2, math.frexp(v.c)) - 1 + (v.forceRender and 0x80 or 0), v.x1, v.y1, v.z1, v.x2, v.y2, v.z2, v.x3, v.y3, v.z3)) end
out.close()