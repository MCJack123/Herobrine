local function sum_table(tab1, tab2)
    if #tab1 ~= #tab2 then error("Size mismatch", 2) end
    local retval = {}
    for k,v in ipairs(tab1) do retval[k] = v + tab2[k] end
    return retval
end

local function prod_table(tab1, tab2)
    if #tab1 ~= #tab2 then error("Size mismatch", 2) end
    local retval = {}
    for k,v in ipairs(tab1) do retval[k] = v * tab2[k] end
    return retval
end

local function sum_number(tab1, num)
    local retval = {}
    for k,v in ipairs(tab1) do retval[k] = v + num end
    return retval
end

local function prod_number(tab1, num)
    local retval = {}
    for k,v in ipairs(tab1) do retval[k] = v * num end
    return retval
end

local function sum_all(tab)
    local res = 0
    for k,v in ipairs(tab) do res = res + v end
    return res
end

local function prod_all(tab)
    local res = 1
    for k,v in ipairs(tab) do res = res * v end
    return res
end

local function sum(tab, b)
    if tab == nil then error("tab is nil", 2) end
    if type(b) == "number" then return sum_number(tab, b)
    elseif b == nil then return sum_all(tab)
    else return sum_table(tab, b) end
end

local function prod(tab, b)
    if tab == nil then error("tab is nil", 2) end
    if type(b) == "number" then return prod_number(tab, b)
    elseif b == nil then return prod_all(tab)
    else return prod_table(tab, b) end
end

local function neg(tab)
    local retval = {}
    for k,v in ipairs(tab) do retval[k] = 0 - v end
    return retval
end

local function inv(tab)
    local retval = {}
    for k,v in ipairs(tab) do retval[k] = 1 / v end
    return retval
end

term.clear()
g = 1
list1 = {12, 24, 23, 22, 21, 20}
local colormap = {
    colors.lightGray,
    colors.lightGray, 
    colors.lightGray, 
    colors.lightGray, 
    colors.lightGray, 
    colors.lightGray, 
    colors.lightGray, 
    colors.lightGray, 
    colors.lightGray, 
    colors.blue, 
    colors.red, 
    colors.black, 
    colors.magenta, 
    colors.green, 
    colors.orange, 
    colors.brown, 
    colors.cyan, 
    colors.lightBlue, 
    colors.yellow, 
    colors.white, 
    colors.lightGray, 
    colors.lightGray, 
    colors.gray, 
    colors.gray
}

package.path = package.path .. ";/lib/?.lua"
local blt = require "betterblittle"
local width, height = term.getSize()
width, height = width * 2, height * 3
local img = {}
local time = tonumber(...)

local abs, floor, sqrt = math.abs, math.floor, math.sqrt

local start = os.epoch "utc"
for it = -math.floor(time*5), math.floor(time*5) do
    for y = 0, (height - 2), 2 * g do
        b = ((height / 2) - y) / height
        for x = 0, (width - 2), 2 * g do
            a = (x - (width / 2) + it) / height

            e = a^2 + b^2 + 1
            f = 2*b - 12
            h = 34.75
            d = f^2 - (4*e*h)

            t = 1 / b
            
            u = a * t
            v = t
            c = abs(floor(u) + floor(v)) % 2

            l = 12
            m = 12
            c = 12 - (t > 0 and 1 or 0) * (c + 1)

            if d >= 0 then
                t = -(f - sqrt(d)) / (2*e)
                i = a*t
                j = -b*t - 1
                k = 6 - t
                m = j / 2

                if m > 0 then
                    m = floor(10 * m)
                    l = list1[1 + floor(m / 2)]
                    m = list1[1 + floor(m / 2 + .5)]
                else
                    m = 12
                end 

                list3 = {i / 1.5, j / 2, k / 1.5}
                list2 = {-a, b, 1}
                s = 10^308.25 * sum(prod(list3, list2))

                list4 = sum(prod(list3, s), neg(list2))
                p = list4[1]
                q = list4[2]
                r = list4[3]

                t = (j + 2) / q

                if t > 0 then
                    u = p*t + i
                    v = r*t + 6 - k
                    c = 11 - (abs(floor(u) + floor(v)) % 2)
                else
                    c = 12
                end
            else
                if t > 0 then
                    e = 1
                    f = 4
                    h = u^2 + v^2 - 12*v + 37.75
                    d = f^2 - 4*e*h
                    l = 12*(d >= 0 and 1 or 0) + c*(d < 0 and 1 or 0)
                    m = l
                end
            end

            c = colormap[c] or colors.red
            l = colormap[l] or colors.red
            m = colormap[m] or colors.red

            if y > 125/170 * height and (c == colors.red or c == colors.blue) then c = colors.black end

            img[height - y - 1] = img[height - y - 1] or {}
            img[height - y - 2] = img[height - y - 2] or {}
            img[height - y - 1][width - x - 1] = c
            img[height - y - 2][width - x - 1] = l
            img[height - y - 1][width - x - 2] = m
            img[height - y - 2][width - x - 2] = c
        end
    end

    term.setCursorPos(1, 1)
    blt.drawBuffer(img, term.current())
    sleep(0.1)
    if (os.epoch "utc" - start) / 1000 > time then break end
end
term.setBackgroundColor(colors.black)
term.setCursorPos(1, 1)
term.clear()