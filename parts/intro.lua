local w, h = term.getSize()
local centerX, centerY = math.floor(w / 2), math.floor(h / 2)
local function centerWrite(y) return function(text)
    term.setCursorPos(math.ceil(centerX - (#text / 2) + 1), centerY + y)
    term.write(text)
end end
term.setBackgroundColor(colors.black)
term.clear()
term.setBackgroundColor(colors.lightGray)
term.setTextColor(colors.black)
centerWrite(-3) " WARNING "
term.setBackgroundColor(colors.black)
term.setTextColor(colors.white)
centerWrite(-1) "This program works best on an advanced computer."
if term.isColor() then
    term.setTextColor(colors.yellow)
    centerWrite(0) "Good thing we have color!"
else
    term.setTextColor(colors.red) -- this won't be red, but it'll be darker
    centerWrite(0) "What are you, poor?"
end
term.setTextColor(colors.white)
centerWrite(2) "It'll look even cooler on a monitor."
if term.current().setTextScale then
    term.setTextColor(colors.green)
    centerWrite(3) "Enjoy the show!"
else
    term.setTextColor(colors.lightBlue) -- this won't be red, but it'll be darker
    centerWrite(3) "Hope you like pixels!"
end
for _ = 1, 5 do
    term.setPaletteColor(colors.lightGray, term.getPaletteColor(colors.white))
    sleep(0.5)
    term.setPaletteColor(colors.lightGray, term.getPaletteColor(colors.black))
    sleep(0.5)
end
term.setPaletteColor(colors.lightGray, term.getPaletteColor(colors.white))
sleep(1)
term.setPaletteColor(colors.lightGray, term.nativePaletteColor(colors.lightGray))
for n = 0.9, 0, -0.1 do
    for i = 0, 15 do
        local r, g, b = term.getPaletteColor(2^i)
        term.setPaletteColor(2^i, r*n, g*n, b*n)
    end
    sleep(0.05)
end
term.clear()
local c = term.nativePaletteColor(colors.black)
for n = 0, c, c / 10 do
    term.setPaletteColor(colors.black, n, n, n)
    sleep(0.05)
end
for i = 0, 15 do term.setPaletteColor(2^i, term.nativePaletteColor(2^i)) end
