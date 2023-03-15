local infile = assert(io.open("loading-base2.dfpwm", "rb"))
local base = infile:read("*a")
infile:close()
infile = assert(io.open("loading-residue2.raw", "rb"))
local residue = infile:read("*a")
infile:close()
base = base:gsub("\x55+", function(s) return "\x55" .. string.char(#s) end):gsub("\xAA+", function(s) return "\xAA" .. string.char(#s) end)
residue = residue:gsub("[\x70-\x8F]+", function(s)
    local n = #s
    local r = ""
    while n > 0 do
        local d = math.min(n, 255)
        r = r .. "\x80" .. string.char(d)
        n = n - d
    end
    return r
end)
local outfile = assert(io.open("loading.mus", "wb"))
outfile:write(("<HH"):pack(#base, #residue))
outfile:write(base)
outfile:write(residue)
outfile:close()