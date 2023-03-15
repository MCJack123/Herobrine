
-- Made by Xella#8655

local arg = ...
local libFolder = arg:match("(.-)[^%.]+$")
local betterblittle = require(libFolder .. "betterblittle")

local colorChar = {}
for i = 1, 16 do
	colorChar[2 ^ (i - 1)] = ("0123456789abcdef"):sub(i, i)
end

local large = math.pow(10, 99)
local function linear(x1, y1, x2, y2)
	local dx = x2 - x1
	if dx == 0 then
		return large, -large * x1
	end
	local a = (y2 - y1) / dx
	return a, y1 - a * x1
end

local min = math.min
local max = math.max
local floor = math.floor
local ceil = math.ceil

---Creates a new Buffer for rendering triangles
---@param x1 number top-left x coordinate of the Buffer on the screen
---@param y1 number top-left y coordinate of the Buffer on the screen
---@param x2 number bottom-right x coordinate of the Buffer on the screen
---@param y2 number bottom-right y coordinate of the Buffer on the screen
---@return Buffer
local function newBuffer(x1, y1, x2, y2)
	---@class Buffer
	local buffer = {
		x1 = x1,
		y1 = y1,
		x2 = x2,
		y2 = y2,
		width = x2 - x1 + 1,
		height = y2 - y1 + 1,
		screenBuffer = {{}},
		blittleWindow = nil,
		blittleOn = false,
		backgroundColor = colors.lightBlue
	}

	---Reposition the Buffer
	---@param newX1 number
	---@param newY1 number
	---@param newX2 number
	---@param newY2 number
	function buffer:setBufferSize(newX1, newY1, newX2, newY2)
		self.x1 = newX1
		self.y1 = newY1

		self.x2 = newX2
		self.y2 = newY2

		self.width = newX2 - newX1 + 1
		self.height = newY2 - newY1 + 1

		if self.blittleWindow then
			self.blittleWindow = self.blittleWindow.reposition(self.x1, self.y1, self.x1 + self.width-1, self.y1 + self.height-1)
		end

		self:clear()
	end

	---Fully clear the Buffer
	function buffer:clear()
		local screenBuffer = self.screenBuffer

		screenBuffer.c2 = {}
		local c2 = screenBuffer.c2

		local width = self.width
		local color = self.backgroundColor

		if self.blittleOn then
			for y = 1, self.height do
				c2[y] = {}
				local c2Y = c2[y]
				for x = 1, width do
					c2Y[x] = color
				end
			end
		else
			local colorC = colorChar[color]

			screenBuffer.c1 = {}
			local c1 = screenBuffer.c1

			screenBuffer.chars = {}
			local chars = screenBuffer.chars

			for y = 1, self.height do
				c1[y] = {}
				c2[y] = {}
				chars[y] = {}
				local c1Y = c1[y]
				local c2Y = c2[y]
				local charsY = chars[y]
				for x = 1, width do
					c1Y[x] = colorC
					c2Y[x] = colorC
					charsY[x] = " "
				end
			end
		end
	end

	---Clear the Buffer quickly without blittle enabled
	function buffer:fastClearNormal()
		local c = self.backgroundColor

		local screenBuffer = self.screenBuffer
		local chars = screenBuffer.chars
		local c1 = screenBuffer.c1
		local c2 = screenBuffer.c2

		local c = colorChar[c]

		local width = self.width
		for y = 1, self.height do
			local charsY = chars[y]
			local c1Y = c1[y]
			local c2Y = c2[y]
			for x = 1, width do
				charsY[x] = " "
				c1Y[x] = c
				c2Y[x] = c
			end
		end
	end

	---Clear the Buffer quickly with blittle enabled
	function buffer:fastClearBLittle()
		local c = self.backgroundColor
		local c2 = self.screenBuffer.c2

		local width = self.width
		for y = 1, self.height do
			local c2Y = c2[y]
			for x = 1, width do
				c2Y[x] = c
			end
		end
	end

	---Set the color of an individual pixel
	---@param x number
	---@param y number
	---@param c1 number color for the pixel
	---@param c2 string? color for the pixel
	---@param char string? char for the pixel
	function buffer:setPixel(x, y, c1, c2, char)
		x = math.floor(x+0.5)
		y = math.floor(y+0.5)

		if x >= 1 and x <= self.width then
			if y >= 1 and y <= self.height then
				local screenBuffer = self.screenBuffer
				if self.blittleOn then
					screenBuffer.c2[y][x] = c2 or c1
				else
					screenBuffer.c1[y][x] = colorChar[c1]
					screenBuffer.c2[y][x] = colorChar[c2 or c1]
					screenBuffer.chars[y][x] = " "
				end
			end
		end
	end

	---@alias PaintUtilsImage table

	---Render an image to the Buffer at a given offset
	---@param dx number
	---@param dy number
	---@param image PaintUtilsImage can be loaded with paintutils.loadImage (from .nfp)
	function buffer:image(dx, dy, image)
		for y, row in pairs(image) do
			for x, value in pairs(row) do
				if value and value > 0 then
					if self.blittleOn then
						self:setPixel(x + (dx - 1) * 2, y + (dy - 1) * 3, value, value, " ")
					else
						self:setPixel(x + dx - 1, y + dy - 1, value, value, " ")
					end
				end
			end
		end
	end

	function buffer:loadLineNormal(x1, y1, x2, y2, c, char, charc, a, b)
		local screenBuffer = self.screenBuffer
		local c1 = screenBuffer.c1
		local c2 = screenBuffer.c2
		local chars = screenBuffer.chars

		local frameWidth = self.width
		local frameHeight = self.height

		if x2 >= x1 then
			for x = max(ceil(x1), 1), min(floor(x2), frameWidth) do
				local y = floor(a * x + b + 0.5)
				if y > 0 and y <= frameHeight then
					c1[y][x] = charc
					c2[y][x] = c
					chars[y][x] = char
				end
			end
		else
			for x = max(ceil(x2), 1), min(floor(x1), frameWidth) do
				local y = floor(a * x + b + 0.5)
				if y > 0 and y <= frameHeight then
					c1[y][x] = charc
					c2[y][x] = c
					chars[y][x] = char
				end
			end
		end

		if y2 >= y1 then
			for y = max(ceil(y1), 1), min(floor(y2), frameHeight) do
				local x = floor((y - b) / a + 0.5)
				if x > 0 and x <= frameWidth then
					c1[y][x] = charc
					c2[y][x] = c
					chars[y][x] = char
				end
			end
		else
			for y = max(ceil(y2), 1), min(floor(y1), frameHeight) do
				local x = floor((y - b) / a + 0.5)
				if x > 0 and x <= frameWidth then
					c1[y][x] = charc
					c2[y][x] = c
					chars[y][x] = char
				end
			end
		end
	end

	function buffer:loadLineBLittle(x1, y1, x2, y2, c, a, b)
		local screenBuffer = self.screenBuffer
		local c2 = screenBuffer.c2

		local frameWidth = self.width
		local frameHeight = self.height

		if x2 >= x1 then
			for x = max(ceil(x1), 1), min(floor(x2), frameWidth) do
				local y = floor(a * x + b + 0.5)
				if y > 0 and y <= frameHeight then
					c2[y][x] = c
				end
			end
		else
			for x = max(ceil(x2), 1), min(floor(x1), frameWidth) do
				local y = floor(a * x + b + 0.5)
				if y > 0 and y <= frameHeight then
					c2[y][x] = c
				end
			end
		end

		if y2 >= y1 then
			for y = max(ceil(y1), 1), min(floor(y2), frameHeight) do
				local x = floor((y - b) / a + 0.5)
				if x > 0 and x <= frameWidth then
					c2[y][x] = c
				end
			end
		else
			for y = max(ceil(y2), 1), min(floor(y1), frameHeight) do
				local x = floor((y - b) / a + 0.5)
				if x > 0 and x <= frameWidth then
					c2[y][x] = c
				end
			end
		end
	end

	local defaultOutlineColor = colors.black

	function buffer:drawTriangleNormal(x1, y1, x2, y2, x3, y3, c, char, charc, outlineColor)
		if x1 < 1 and x2 < 1 and x3 < 1 or y1 < 1 and y2 < 1 and y3 < 1 then return end
		local frameWidth = self.width
		if x1 > frameWidth and x2 > frameWidth and x3 > frameWidth then return end
		local frameHeight = self.height
		if y1 > frameHeight and y2 > frameHeight and y3 > frameHeight then return end

		if y1 > y2 then
			y1, y2 = y2, y1
			x1, x2 = x2, x1
		end
		if y2 > y3 then
			y3, y2 = y2, y3
			x3, x2 = x2, x3
		end
		if y1 > y2 then
			y1, y2 = y2, y1
			x1, x2 = x2, x1
		end

		local screenBuffer = self.screenBuffer

		local floor, ceil = floor, ceil
		local min, max = min, max

		local minY = min(max(1, ceil(y1)), frameHeight)
		local midY = min(max(0, floor(y2)), frameHeight)
		local maxY = min(max(1, floor(y3)), frameHeight)

		local c1 = screenBuffer.c1
		local c2 = screenBuffer.c2
		local chars = screenBuffer.chars

		local x2_x1_div_y2_y1 = (x2 - x1) / (y2 - y1)
		local x1_x3_div_y1_y3 = (x1 - x3) / (y1 - y3)

		char = char or " "
		charc = charc or c
		local c = colorChar[c]
		local charc = colorChar[charc]

		for y = minY, midY do
			local c1Y = c1[y]
			local c2Y = c2[y]
			local charsY = chars[y]

			local xA = (y - y1) * x2_x1_div_y2_y1 + x1
			local xB = (y - y3) * x1_x3_div_y1_y3 + x3
			if xB < xA then xA, xB = xB, xA end

			if xA < 1 then xA = 1 end
			if xA > frameWidth then xA = frameWidth end
			if xB < 1 then xB = 1 end
			if xB > frameWidth then xB = frameWidth end

			for x = floor(xA+0.5), floor(xB+0.5) do
				c1Y[x] = charc
				c2Y[x] = c
				charsY[x] = char
			end
		end

		local x3_x2_div_y3_y2 = (x3 - x2) / (y3 - y2)
		local x1_x3_div_y1_y3 = (x1 - x3) / (y1 - y3)

		for y = midY+1, maxY do
			local c1Y = c1[y]
			local c2Y = c2[y]
			local charsY = chars[y]

			local xA = (y - y2) * x3_x2_div_y3_y2 + x2
			local xB = (y - y3) * x1_x3_div_y1_y3 + x3
			if xB < xA then xA, xB = xB, xA end

			if xA < 1 then xA = 1 end
			if xA > frameWidth then xA = frameWidth end
			if xB < 1 then xB = 1 end
			if xB > frameWidth then xB = frameWidth end

			for x = floor(xA+0.5), floor(xB+0.5) do
				c1Y[x] = charc
				c2Y[x] = c
				charsY[x] = char
			end
		end

		local outlineColor = outlineColor
		if outlineColor or self.triangleEdges then
			local a1, b1 = linear(x1, y1, x2, y2)
			local a2, b2 = linear(x2, y2, x3, y3)
			local a3, b3 = linear(x1, y1, x3, y3)

			local loadLine = self.loadLineNormal
			local c = colorChar[outlineColor or defaultOutlineColor]
			loadLine(self, x1, y1, x2, y2, c, char, charc, a1, b1)
			loadLine(self, x2, y2, x3, y3, c, char, charc, a2, b2)
			loadLine(self, x3, y3, x1, y1, c, char, charc, a3, b3)
		end
	end

	function buffer:drawTriangleBLittle(x1, y1, x2, y2, x3, y3, c, char, charc, outlineColor)
		if x1 < 1 and x2 < 1 and x3 < 1 or y1 < 1 and y2 < 1 and y3 < 1 then return end
		local frameWidth = self.width
		if x1 > frameWidth and x2 > frameWidth and x3 > frameWidth then return end
		local frameHeight = self.height
		if y1 > frameHeight and y2 > frameHeight and y3 > frameHeight then return end

		if y1 > y2 then
			y1, y2 = y2, y1
			x1, x2 = x2, x1
		end
		if y2 > y3 then
			y3, y2 = y2, y3
			x3, x2 = x2, x3
		end
		if y1 > y2 then
			y1, y2 = y2, y1
			x1, x2 = x2, x1
		end

		local screenBuffer = self.screenBuffer

		local floor, ceil = floor, ceil
		local min, max = min, max

		local minY = min(max(1, ceil(y1)), frameHeight)
		local midY = min(max(0, floor(y2)), frameHeight)
		local maxY = min(max(1, floor(y3)), frameHeight)

		local c2 = screenBuffer.c2

		local x2_x1_div_y2_y1 = (x2 - x1) / (y2 - y1)
		local x1_x3_div_y1_y3 = (x1 - x3) / (y1 - y3)

		if y1 ~= y2 and y1 ~= y3 then
			for y = minY, midY do
				local c2Y = c2[y]

				local xA = (y - y1) * x2_x1_div_y2_y1 + x1
				local xB = (y - y3) * x1_x3_div_y1_y3 + x3
				if xB < xA then xA, xB = xB, xA end

				if xA < 1 then xA = 0 end
				if xA > frameWidth then xA = frameWidth + 1 end
				if xB < 1 then xB = 0 end
				if xB > frameWidth then xB = frameWidth + 1 end

				for x = floor(xA+0.5), floor(xB+0.5) do
					c2Y[x] = c
				end
			end
		end

		local x3_x2_div_y3_y2 = (x3 - x2) / (y3 - y2)
		local x1_x3_div_y1_y3 = (x1 - x3) / (y1 - y3)

		if y3 ~= y2 and y1 ~= y3 then
			for y = midY+1, maxY do
				local c2Y = c2[y]

				local xA = (y - y2) * x3_x2_div_y3_y2 + x2
				local xB = (y - y3) * x1_x3_div_y1_y3 + x3
				if xB < xA then xA, xB = xB, xA end

				if xA < 1 then xA = 0 end
				if xA > frameWidth then xA = frameWidth + 1 end
				if xB < 1 then xB = 0 end
				if xB > frameWidth then xB = frameWidth + 1 end

				for x = floor(xA+0.5), floor(xB+0.5) do
					c2Y[x] = c
				end
			end
		end

		local outlineColor = outlineColor
		if outlineColor or self.triangleEdges then
			local a1, b1 = linear(x1, y1, x2, y2)
			local a2, b2 = linear(x2, y2, x3, y3)
			local a3, b3 = linear(x1, y1, x3, y3)

			local loadLine = self.loadLineBLittle
			local c = outlineColor or defaultOutlineColor
			loadLine(self, x1, y1, x2, y2, c, a1, b1)
			loadLine(self, x2, y2, x3, y3, c, a2, b2)
			loadLine(self, x3, y3, x1, y1, c, a3, b3)
		end
	end

	function buffer:drawBufferNormal()
		local x1 = self.x1
		local y1 = self.y1

		local screenBuffer = self.screenBuffer
		local setCursorPos = term.setCursorPos
		local blit = term.blit

		local chars = screenBuffer.chars
		local c1 = screenBuffer.c1
		local c2 = screenBuffer.c2
		local concat = table.concat
		for y = 1, self.height do
			setCursorPos(x1, y + y1 - 1)

			local chars = concat(chars[y])
			local c1 = concat(c1[y])
			local c2 = concat(c2[y])

			blit(chars, c1, c2)
		end
	end

	function buffer:drawBufferBLittle()
		local blittleWindow = self.blittleWindow
		if not blittleWindow then
			self.blittleWindow = window.create(term.current(), self.x1, self.y1, self.x1 + self.width-1, self.y1 + self.height-1, false)
			blittleWindow = self.blittleWindow
		end

		betterblittle.drawBuffer(self.screenBuffer.c2, blittleWindow)
		---@diagnostic disable-next-line: need-check-nil
		blittleWindow.setVisible(true)
		---@diagnostic disable-next-line: need-check-nil
		blittleWindow.setVisible(false)
	end

	function buffer:highResMode(enabled)
		self.blittleOn = enabled
		self.drawTriangle = enabled and self.drawTriangleBLittle or self.drawTriangleNormal
		self.fastClear = enabled and self.fastClearBLittle or self.fastClearNormal
		self.drawBuffer = enabled and self.drawBufferBLittle or self.drawBufferNormal
		self:clear()
	end

	function buffer:useTriangleEdges(enabled)
		self.triangleEdges = enabled
	end

	buffer:highResMode(true)

	return buffer
end

local sort = table.sort
local function swapPoly16(a, b, table)
	if table[a] == nil or table[b] == nil then
		return false
	end
	if table[a][16] < table[b][16] then
		table[a], table[b] = table[b], table[a]
		return true
	end
	return false
end

local function bubblesort16(array)
	for i = 1, #array do
		local ci = i
		while swapPoly16(ci, ci+1, array) do
			ci = ci - 1
		end
	end
end

local function getCorrect16(array)
	local n = #array
	local correct = 0
	local prevVal = array[1][16]
	for i = 2, n do
		local val = array[i][16]
		if val <= prevVal then
			correct = correct + 1
		end
		prevVal = val
	end
	local correctRatio = correct / (n-1)
	return correctRatio
end

local a=8;local function b(c)local d=0;while c>=a do d=bit.bor(d,bit.band(c,1))c=bit.brshift(c,1)end;return c+d end;local function e(f,g,h)for i=g+1,h do local j=f[i]local k=j[16]local l=i-1;while l>=g and f[l][16]>k do f[l+1]=f[l]l=l-1 end;f[l+1]=j end end;local function m(f,g,h,n,o,d)local p=o-n+1;local q=d-o;for r=0,p-1 do g[r]=f[n+r]end;for r=0,q-1 do h[r]=f[o+1+r]end;local i=0;local l=0;local s=n;while i<p and l<q do if g[i][16]<=h[l][16]then f[s]=g[i]i=i+1 else f[s]=h[l]l=l+1 end;s=s+1 end;while i<p do f[s]=g[i]s=s+1;i=i+1 end;while l<q do f[s]=h[l]s=s+1;l=l+1 end end;local function timsort16(f)local c=#f;local t=b(a)local u=math.min;for i=1,c,t do e(f,i,u(i+a-1,c))end;local v,w={},{}local x=t;while x<=c do for g=1,c,2*x do local y=g+x-1;local h=u(y+x,c)if y<h then m(f,v,w,g,y,h)end end;x=2*x end;for i=1,math.floor(c/2)do f[i],f[c-i+1]=f[c-i+1],f[i]end end

---Sorts the polygons from back to front relative to the Camera
---@param polygons Polygon[]
---@param objectX number
---@param objectY number
---@param objectZ number
---@param camera CollapsedCamera
local function sortPolygons(polygons, objectX, objectY, objectZ, camera)
	local camX = camera[1]
	local camY = camera[2]
	local camZ = camera[3]
	local rx = objectX and (objectX - camX) or 0
	local ry = objectY and (objectY - camY) or 0
	local rz = objectZ and (objectZ - camZ) or 0

	for i = 1, #polygons do
		local polygon = polygons[i]

		local avgX = rx + (polygon[1] + polygon[4] + polygon[7]) / 3
		local avgY = ry + (polygon[2] + polygon[5] + polygon[8]) / 3
		local avgZ = rz + (polygon[3] + polygon[6] + polygon[9]) / 3

		polygon[16] = avgX*avgX + avgY*avgY + avgZ*avgZ -- relative distance
	end

	local correctRatio = getCorrect16(polygons)

	if correctRatio == 1 then
	elseif correctRatio > 0.7 then
		bubblesort16(polygons)
	else
		timsort16(polygons)
	end
end

local rad = math.rad
local sin = math.sin
local cos = math.cos
local function rotatePolygonX(x, y, z, rotS, rotC)
	local z2 = rotC * z - rotS * y
	local y = rotS * z + rotC * y
	local z = z2
	return x, y, z
end
local function rotatePolygonY(x, y, z, rotS, rotC)
	local z2 = rotC * z - rotS * x
	local x = rotS * z + rotC * x
	local z = z2
	return x, y, z
end
local function rotatePolygonZ(x, y, z, rotS, rotC)
	local y2 = rotC * y - rotS * x
	local x = rotS * y + rotC * x
	local y = y2
	return x, y
end

---Rotates a given CollapsedModel around three axes
---@param model CollapsedModel
---@param rotX number?
---@param rotY number?
---@param rotZ number?
---@return CollapsedModel
local function rotateCollapsedModel(model, rotX, rotY, rotZ)
	local rotXS, rotXC = 0, 1
	local rotYS, rotYC = 0, 1
	local rotZS, rotZC = 0, 1

	if rotX == 0 then rotX = nil end
	if rotX then rotXS, rotXC = sin(rotX), cos(rotX) end
	if rotY == 0 then rotY = nil end
	if rotY then rotYS, rotYC = sin(rotY), cos(rotY) end
	if rotZ == 0 then rotZ = nil end
	if rotZ then rotZS, rotZC = sin(rotZ), cos(rotZ) end

	local rotatedModel = {}

	for _, polygon in pairs(model) do
		local x1, y1, z1 = polygon[1], polygon[2], polygon[3]
		local x2, y2, z2 = polygon[4], polygon[5], polygon[6]
		local x3, y3, z3 = polygon[7], polygon[8], polygon[9]

		if rotY then
			x1, y1, z1 = rotatePolygonY(x1, y1, z1, rotYS, rotYC)
			x2, y2, z2 = rotatePolygonY(x2, y2, z2, rotYS, rotYC)
			x3, y3, z3 = rotatePolygonY(x3, y3, z3, rotYS, rotYC)
		end

		if rotZ then
			x1, y1 = rotatePolygonZ(x1, y1, z1, rotZS, rotZC)
			x2, y2 = rotatePolygonZ(x2, y2, z2, rotZS, rotZC)
			x3, y3 = rotatePolygonZ(x3, y3, z3, rotZS, rotZC)
		end

		if rotX then
			x1, y1, z1 = rotatePolygonX(x1, y1, z1, rotXS, rotXC)
			x2, y2, z2 = rotatePolygonX(x2, y2, z2, rotXS, rotXC)
			x3, y3, z3 = rotatePolygonX(x3, y3, z3, rotXS, rotXC)
		end

		rotatedModel[#rotatedModel+1] = {x1, y1, z1, x2, y2, z2, x3, y3, z3}
		rotatedModel[#rotatedModel][10] = polygon[10]
		rotatedModel[#rotatedModel][11] = polygon[11]
		rotatedModel[#rotatedModel][12] = polygon[12]
		rotatedModel[#rotatedModel][13] = polygon[13]
		rotatedModel[#rotatedModel][14] = polygon[14]
		rotatedModel[#rotatedModel][15] = polygon[15]
	end

	return rotatedModel
end

local function swap10(a, b, table)
	if table[a] == nil or table[b] == nil then
		return false
	end
	if table[a][10] < table[b][10] then
		table[a], table[b] = table[b], table[a]
		return true
	end
	return false
end

local function bubblesort10(array)
	for i = 1, #array do
		local ci = i
		while swap10(ci, ci+1, array) do
			ci = ci - 1
		end
	end
end

local function getCorrect10(array)
	local n = #array
	local correct = 0
	local prevVal = array[1][10]
	for i = 2, n do
		local val = array[i][10]
		if val <= prevVal then
			correct = correct + 1
		end
		prevVal = val
	end
	local correctRatio = correct / (n-1)
	return correctRatio
end

local function sortObjects(objects, camera)
	local cX = camera[1]
	local cY = camera[2]
	local cZ = camera[3]

	for i = 1, #objects do
		local object = objects[i]

		local oX = object[1]
		local oY = object[2]
		local oZ = object[3]
		local dX = oX and (oX - cX) or 0
		local dY = oY and (oY - cY) or 0
		local dZ = oZ and (oZ - cZ) or 0

		object[10] = dX*dX + dY*dY + dZ*dZ -- relative distance
	end

	local correctRatio = getCorrect10(objects)

	if correctRatio == 1 then
	elseif correctRatio > 0.7 then
		bubblesort10(objects)
	else
		sort(objects, function(a, b) return a[10] > b[10] end)
	end
end

local transforms = {}
---Model Inverts the direction of all triangles
---@param model Model
---@return Model
function transforms.invertTriangles(model)
	if not model or type(model) ~= "table" then
		error("transforms.invertTriangles expected arg#1 to be a table (model)")
	end

	-- ---@class Model
	-- local newModel = {}
	-- for i = 1, #model do
	-- 	local triangle = model[i]
	-- 	local newTriangle = {
	-- 		x1 = triangle.x1,
	-- 		y1 = triangle.y1,
	-- 		z1 = triangle.z1,
	-- 		x2 = triangle.x3,
	-- 		y2 = triangle.y3,
	-- 		z2 = triangle.z3,
	-- 		x3 = triangle.x2,
	-- 		y3 = triangle.y2,
	-- 		z3 = triangle.z2,
	-- 		c = triangle.c,
	-- 		char = triangle.char,
	-- 		charc = triangle.charc,
	-- 		forceRender = triangle.forceRender,
	-- 		outlineColor = triangle.outlineColor,
	-- 	}
	-- 	newModel[i] = newTriangle
	-- end
	-- return newModel

	for i = 1, #model do
		local triangle = model[i]
		model[i] = {
			x1 = triangle.x1,
			y1 = triangle.y1,
			z1 = triangle.z1,
			x2 = triangle.x3,
			y2 = triangle.y3,
			z2 = triangle.z3,
			x3 = triangle.x2,
			y3 = triangle.y2,
			z3 = triangle.z2,
			c = triangle.c,
			char = triangle.char,
			charc = triangle.charc,
			forceRender = triangle.forceRender,
			outlineColor = triangle.outlineColor,
		}
	end
	return model
end

---Change the outline colors of polygons in a Model
---@param model Model
---@param col number|table if number, will set the outline color for each Polygon, if table, uses it as a mapping from Polygon color to new outline color
---@return Model
function transforms.setOutline(model, col)
	if not model or type(model) ~= "table" then
		error("transforms.invertTriangles expected arg#1 to be a table (model)")
	end

	for i = 1, #model do
		local triangle = model[i]
		if type(col) == "table" then -- colormap
			triangle.outlineColor = col[triangle.c] or triangle.outlineColor
		else
			triangle.outlineColor = col
		end
	end
	return model
end

---Change the colors of polygons in a Model
---@param model Model
---@param col number|table if number, will set the color for each Polygon, if table, uses it as a mapping from Polygon color to new the new color
---@return Model
function transforms.mapColor(model, col)
	if not model or type(model) ~= "table" then
		error("transforms.mapColor expected arg#1 to be a table (model)")
	end

	for i = 1, #model do
		local triangle = model[i]
		if type(col) == "table" then -- colormap
			triangle.c = col[triangle.c] or triangle.c
		else
			triangle.c = col
		end
	end
	return model
end

---Center the Model such that the origin is in the middle of the bounding box
---@param model Model
function transforms.center(model)
	local minX, maxX = math.huge, -math.huge
	local minY, maxY = math.huge, -math.huge
	local minZ, maxZ = math.huge, -math.huge

	for i = 1, #model do
		local poly = model[i]
		minX, maxX = min(minX, poly.x1), max(maxX, poly.x1)
		minX, maxX = min(minX, poly.x2), max(maxX, poly.x2)
		minX, maxX = min(minX, poly.x3), max(maxX, poly.x3)
		minY, maxY = min(minY, poly.y1), max(maxY, poly.y1)
		minY, maxY = min(minY, poly.y2), max(maxY, poly.y2)
		minY, maxY = min(minY, poly.y3), max(maxY, poly.y3)
		minZ, maxZ = min(minZ, poly.z1), max(maxZ, poly.z1)
		minZ, maxZ = min(minZ, poly.z2), max(maxZ, poly.z2)
		minZ, maxZ = min(minZ, poly.z3), max(maxZ, poly.z3)
	end

	local offsetX = -(maxX + minX)*0.5
	local offsetY = -(maxY + minY)*0.5
	local offsetZ = -(maxZ + minZ)*0.5

	for i = 1, #model do
		local poly = model[i]
		poly.x1 = poly.x1 + offsetX
		poly.x2 = poly.x2 + offsetX
		poly.x3 = poly.x3 + offsetX
		poly.y1 = poly.y1 + offsetY
		poly.y2 = poly.y2 + offsetY
		poly.y3 = poly.y3 + offsetY
		poly.z1 = poly.z1 + offsetZ
		poly.z2 = poly.z2 + offsetZ
		poly.z3 = poly.z3 + offsetZ
	end

	return model
end

---Rescales the model such that the largest value of any coordinate is equal to 1
---@param model Model
function transforms.normalizeScale(model)
	local maxVal = -math.huge

	for i = 1, #model do
		local poly = model[i]
		maxVal = max(maxVal, poly.x1)
		maxVal = max(maxVal, poly.x2)
		maxVal = max(maxVal, poly.x3)
		maxVal = max(maxVal, poly.y1)
		maxVal = max(maxVal, poly.y2)
		maxVal = max(maxVal, poly.y3)
		maxVal = max(maxVal, poly.z1)
		maxVal = max(maxVal, poly.z2)
		maxVal = max(maxVal, poly.z3)
	end

	for i = 1, #model do
		local poly = model[i]
		poly.x1 = poly.x1 / maxVal
		poly.x2 = poly.x2 / maxVal
		poly.x3 = poly.x3 / maxVal
		poly.y1 = poly.y1 / maxVal
		poly.y2 = poly.y2 / maxVal
		poly.y3 = poly.y3 / maxVal
		poly.z1 = poly.z1 / maxVal
		poly.z2 = poly.z2 / maxVal
		poly.z3 = poly.z3 / maxVal
	end

	return model
end

---Similar to normalizeScale, rescales the model, but only uses the y coordinate to determine how much it is scaled (normalizes height)
---@param model Model
function transforms.normalizeScaleY(model)
	local maxVal = -math.huge

	for i = 1, #model do
		local poly = model[i]
		maxVal = max(maxVal, poly.y1)
		maxVal = max(maxVal, poly.y2)
		maxVal = max(maxVal, poly.y3)
	end

	for i = 1, #model do
		local poly = model[i]
		poly.x1 = poly.x1 / maxVal
		poly.x2 = poly.x2 / maxVal
		poly.x3 = poly.x3 / maxVal
		poly.y1 = poly.y1 / maxVal
		poly.y2 = poly.y2 / maxVal
		poly.y3 = poly.y3 / maxVal
		poly.z1 = poly.z1 / maxVal
		poly.z2 = poly.z2 / maxVal
		poly.z3 = poly.z3 / maxVal
	end

	return model
end

---Scales the model
---@param model Model
---@param scale number
function transforms.scale(model, scale)
	for i = 1, #model do
		local poly = model[i]
		poly.x1 = poly.x1 * scale
		poly.x2 = poly.x2 * scale
		poly.x3 = poly.x3 * scale
		poly.y1 = poly.y1 * scale
		poly.y2 = poly.y2 * scale
		poly.y3 = poly.y3 * scale
		poly.z1 = poly.z1 * scale
		poly.z2 = poly.z2 * scale
		poly.z3 = poly.z3 * scale
	end

	return model
end

---Translates the model
---@param model Model
---@param dx number?
---@param dy number?
---@param dz number?
function transforms.translate(model, dx, dy, dz)
	for i = 1, #model do
		local poly = model[i]
		poly.x1 = poly.x1 + (dx or 0)
		poly.x2 = poly.x2 + (dx or 0)
		poly.x3 = poly.x3 + (dx or 0)
		poly.y1 = poly.y1 + (dy or 0)
		poly.y2 = poly.y2 + (dy or 0)
		poly.y3 = poly.y3 + (dy or 0)
		poly.z1 = poly.z1 + (dz or 0)
		poly.z2 = poly.z2 + (dz or 0)
		poly.z3 = poly.z3 + (dz or 0)
	end

	return model
end

---Rotates a given Model around three axes
---@param model Model
---@param rotX number? in radians
---@param rotY number? in radians
---@param rotZ number? in radians
---@return Model
function transforms.rotate(model, rotX, rotY, rotZ)
	local rotXS, rotXC = 0, 1
	local rotYS, rotYC = 0, 1
	local rotZS, rotZC = 0, 1

	if rotX == 0 then rotX = nil end
	if rotX then rotXS, rotXC = sin(rotX), cos(rotX) end
	if rotY == 0 then rotY = nil end
	if rotY then rotYS, rotYC = sin(rotY), cos(rotY) end
	if rotZ == 0 then rotZ = nil end
	if rotZ then rotZS, rotZC = sin(rotZ), cos(rotZ) end

	for i = 1, #model do
		local polygon = model[i]

		local x1, y1, z1 = polygon.x1, polygon.y1, polygon.z1
		local x2, y2, z2 = polygon.x2, polygon.y2, polygon.z2
		local x3, y3, z3 = polygon.x3, polygon.y3, polygon.z3

		if rotY then
			x1, y1, z1 = rotatePolygonY(x1, y1, z1, rotYS, rotYC)
			x2, y2, z2 = rotatePolygonY(x2, y2, z2, rotYS, rotYC)
			x3, y3, z3 = rotatePolygonY(x3, y3, z3, rotYS, rotYC)
		end

		if rotZ then
			x1, y1 = rotatePolygonZ(x1, y1, z1, rotZS, rotZC)
			x2, y2 = rotatePolygonZ(x2, y2, z2, rotZS, rotZC)
			x3, y3 = rotatePolygonZ(x3, y3, z3, rotZS, rotZC)
		end

		if rotX then
			x1, y1, z1 = rotatePolygonX(x1, y1, z1, rotXS, rotXC)
			x2, y2, z2 = rotatePolygonX(x2, y2, z2, rotXS, rotXC)
			x3, y3, z3 = rotatePolygonX(x3, y3, z3, rotXS, rotXC)
		end

		polygon.x1, polygon.y1, polygon.z1 = x1, y1, z1
		polygon.x2, polygon.y2, polygon.z2 = x2, y2, z2
		polygon.x3, polygon.y3, polygon.z3 = x3, y3, z3
	end

	return model
end

---Translates the model such that the bottom aligns with y = 0
---@param model Model
function transforms.alignBottom(model)
	local minY = math.huge

	for i = 1, #model do
		local poly = model[i]
		minY = min(minY, poly.y1)
		minY = min(minY, poly.y2)
		minY = min(minY, poly.y3)
	end

	for i = 1, #model do
		local poly = model[i]
		poly.y1 = poly.y1 - minY
		poly.y2 = poly.y2 - minY
		poly.y3 = poly.y3 - minY
	end

	return model
end

---Triangle decimation (reduce the quality / number of polygons in a model), default mode "ratio"
---@param model Model
---@param quality number
---@param mode? "ratio"|"polys"
---@return Model
function transforms.decimate(model, quality, mode)
	-- convert model format

	local vertices = {}
	local triangles = {}

	local function findVertex(x, y, z)
		for i = #vertices, 1, -1 do
			local vertex = vertices[i]
			if vertex[1] == x and vertex[2] == y and vertex[3] == z then
				return i
			end
		end
	end

	for i = 1, #model do
		local poly = model[i]

		local i1 = findVertex(poly.x1, poly.y1, poly.z1)
		if not i1 then
			vertices[#vertices+1] = {poly.x1, poly.y1, poly.z1}
			i1 = #vertices
		end

		local i2 = findVertex(poly.x2, poly.y2, poly.z2)
		if not i2 then
			vertices[#vertices+1] = {poly.x2, poly.y2, poly.z2}
			i2 = #vertices
		end

		local i3 = findVertex(poly.x3, poly.y3, poly.z3)
		if not i3 then
			vertices[#vertices+1] = {poly.x3, poly.y3, poly.z3}
			i3 = #vertices
		end

		local triangle = {i1, i2, i3, poly.c, poly.char, poly.charc, poly.forceRender}
		triangles[#triangles+1] = triangle
	end

	-- actually decimate

	local function getDistance(v1, v2)
		local dx = v1[1] - v2[1]
		local dy = v1[2] - v2[2]
		local dz = v1[3] - v2[3]
		return (dx*dx + dy*dy + dz*dz)^0.5
	end

	---@type EdgeCandidate[]
	local candidateEdges = {}
	for i = 1, #triangles do
		local triangle = triangles[i]
		local edge1Length = getDistance(
			vertices[triangle[1]],
			vertices[triangle[2]]
		)
		local edge2Length = getDistance(
			vertices[triangle[2]],
			vertices[triangle[3]]
		)
		local edge3Length = getDistance(
			vertices[triangle[1]],
			vertices[triangle[3]]
		)

		---@class EdgeCandidate
		candidateEdges[#candidateEdges+1] = {
			length = edge1Length,
			vA = triangle[1],
			vB = triangle[2],
		}

		candidateEdges[#candidateEdges+1] = {
			length = edge2Length,
			vA = triangle[2],
			vB = triangle[3],
		}

		candidateEdges[#candidateEdges+1] = {
			length = edge3Length,
			vA = triangle[1],
			vB = triangle[3],
		}
	end

	local function collapseEdge(vA, vB)
		local vertex1 = vertices[vA]
		local vertex2 = vertices[vB]
		local vertexNew = { -- TODO: Maybe don't use average position, but offset in a smart way?
			(vertex1[1] + vertex2[1])*0.5,
			(vertex1[2] + vertex2[2])*0.5,
			(vertex1[3] + vertex2[3])*0.5,
		}
		vertices[#vertices+1] = vertexNew
		local vNew = #vertices

		for i = #triangles, 1, -1 do
			local tri = triangles[i]
			if tri[1] == vA or tri[1] == vB or tri[2] == vA or tri[2] == vB or tri[3] == vA or tri[3] == vB then
				-- triangle contains at least one of the vertices being collapsed

				if tri[1] == vA or tri[1] == vB then
					tri[1] = vNew
				end
				if tri[2] == vA or tri[2] == vB then
					tri[2] = vNew
				end
				if tri[3] == vA or tri[3] == vB then
					tri[3] = vNew
				end

				if tri[1] == tri[2] or tri[2] == tri[3] or tri[1] == tri[3] then
					-- no longer valid triangle
					table.remove(triangles, i)
				end
			end
		end

		return vNew
	end

	local maxTriangles = quality
	if mode ~= "polys" then
		maxTriangles = (#model) * quality
	end
	while #triangles > maxTriangles do
		-- find smallest edge
		local smallestLength = math.huge
		local smallestIndex
		for i = 1, #candidateEdges do
			local candidate = candidateEdges[i]
			if candidate.length < smallestLength then
				smallestLength = candidate.length
				smallestIndex = i
			end
		end
		local smallestCandidate = candidateEdges[smallestIndex]

		-- collapse smallest edge
		local vNew = collapseEdge(smallestCandidate.vA, smallestCandidate.vB)

		-- remove now invalid candidate edges
		for i = #candidateEdges, 1, -1 do
			local candidate = candidateEdges[i]
			local replaced1 = candidate.vA == smallestCandidate.vA or candidate.vA == smallestCandidate.vB
			local replaced2 = candidate.vB == smallestCandidate.vA or candidate.vB == smallestCandidate.vB
			if replaced1 and replaced2 then
				table.remove(candidateEdges, i)
			elseif replaced1 then
				candidate.vA = vNew
			elseif replaced2 then
				candidate.vB = vNew
			end
		end
	end

	-- build new model

	---@class Model
	---@field invertTriangles fun(self: Model): Model Inverts the direction of all triangles
	---@field setOutline fun(self: Model, col: number|table): Model Change the outline colors of polygons in a Model. If number, will set the outline color for each Polygon, if table, uses it as a mapping from Polygon color to new outline color
	---@field mapColor fun(self: Model, col: number|table): Model Change the colors of polygons in a Model. If number, will set the color for each Polygon, if table, uses it as a mapping from Polygon color to new the new color
	---@field center fun(self: Model): Model Center the Model such that the origin is in the middle of the bounding box
	---@field normalizeScale fun(self: Model): Model Rescales the model such that the largest value of any coordinate is equal to 1
	---@field normalizeScaleY fun(self: Model): Model Similar to normalizeScale, rescales the model, but only uses the y coordinate to determine how much it is scaled (normalizes height)
	---@field scale fun(self: Model, scale: number): Model Scales the model
	---@field translate fun(self: Model, dx: number?, dy: number?, dz: number?): Model Translates the model
	---@field rotate fun(self: Model, rotX: number?, rotY: number?, rotZ: number?): Model Rotates a given Model around three axes (radians)
	---@field alignBottom fun(self: Model): Model Translates the model such that the bottom aligns with y = 0
	---@field decimate fun(self: Model, quality: number, mode?: "ratio"|"polys"): Model Triangle decimation (reduce the quality / number of polygons in a model)
	---@field toLoD fun(self: Model, settings: {minQuality: number?, variantCount: number?, qualityHalvingDistance: number?, quickInitWorseRuntime: boolean?}?): LoDModel Create a new Level of Detail Model
	local newModel = {}

	for i = 1, #triangles do
		local triangle = triangles[i]
		local v1 = vertices[triangle[1]]
		local v2 = vertices[triangle[2]]
		local v3 = vertices[triangle[3]]

		newModel[#newModel+1] = {
			x1 = v1[1],
			y1 = v1[2],
			z1 = v1[3],
			x2 = v2[1],
			y2 = v2[2],
			z2 = v2[3],
			x3 = v3[1],
			y3 = v3[2],
			z3 = v3[3],
			c = triangle[4],
			char = triangle[5],
			charc = triangle[6],
			forceRender = triangle[7],
		}
	end

	for name, func in pairs(transforms) do
		newModel[name] = func
	end

	return newModel
end

local loadModel, loadModelRaw

---Create a new Level of Detail Model
---@param settings {minQuality: number?, variantCount: number?, qualityHalvingDistance: number?, quickInitWorseRuntime: boolean?}?
---@return LoDModel
function transforms.toLoD(model, settings)
	settings = settings or {}

	---@class LoDModel
	local LoDModel = {
		minQuality = settings.minQuality or 0.1,
		variantCount = settings.variantCount or 4,
		qualityHalvingDistance = settings.qualityHalvingDistance or 5,
		quickInitWorseRuntime = settings.quickInitWorseRuntime or false,
	}

	local objModel, modelSize = loadModelRaw(model)

	---@type LoDVariant[]
	local modelVariants = {
		{
			quality = 1,
			collapsedModel = objModel,
			size = modelSize,
		}
	}

	local prevQuality = model
	local originalPolyCount = #prevQuality

	for i = 1, LoDModel.variantCount do
		local quality = (1 - LoDModel.minQuality) * (1 - i / LoDModel.variantCount) + LoDModel.minQuality

		local polyCount = math.floor(originalPolyCount*quality + 0.5)
		local decreasedQualityModel = prevQuality:decimate(polyCount, "polys")
		local objModel, modelSize = loadModelRaw(decreasedQualityModel)
		prevQuality = decreasedQualityModel

		---@class LoDVariant
		local var = {
			quality = quality,
			collapsedModel = objModel,
			size = modelSize,
		}

		modelVariants[#modelVariants+1] = var
	end

	local function copyVariants(vars)
		local newVars = {}
		for i = 1, #vars do
			local var = vars[i]
			local model = var.collapsedModel

			local modelNew = {}
			for j = 1, #model do
				local poly = model[j]
				local polyNew = {
					poly[1],
					poly[2],
					poly[3],
					poly[4],
					poly[5],
					poly[6],
					poly[7],
					poly[8],
					poly[9],
					poly[10],
					poly[11],
					poly[12],
					poly[13],
					poly[14],
				}
				modelNew[j] = polyNew
			end

			local varNew = {
				quality = var.quality,
				size = var.size,
				collapsedModel = modelNew,
			}

			newVars[i] = varNew
		end
		return newVars
	end

	---@type LoDVariant[][]
	local objectVariants = {}

	---[INTERNAL] initialize new PineObject
	---@param object PineObject
	function LoDModel:initObject(object)
		local variants
		if LoDModel.quickInitWorseRuntime then
			variants = modelVariants
		else
			variants = copyVariants(modelVariants)
		end
		objectVariants[object] = variants

		object[7] = variants[1].collapsedModel
		object[8] = variants[1].size
		object[9] = LoDModel
	end

	---Update the LoD for a table of objects with respect to a camera position
	---@param object PineObject
	---@param camera CollapsedCamera
	function LoDModel:update(object, camera)
		local variants = objectVariants[object]

		if variants then
			local dx = camera[1] - object[1]
			local dy = camera[2] - object[2]
			local dz = camera[3] - object[3]
			local d = (dx*dx + dy*dy + dz*dz)^0.5
			local targetQuality = math.min(1, math.max(LoDModel.minQuality, 1 / (d/LoDModel.qualityHalvingDistance)))
			local closestRaw = (LoDModel.variantCount + 1) - LoDModel.variantCount * (targetQuality - LoDModel.minQuality) / (1 - LoDModel.minQuality)
			local closest = math.floor(closestRaw + 0.5)

			local var = variants[closest]
			object[7] = var.collapsedModel
			object[8] = var.size
		end
	end

	return LoDModel
end

local sqrt = math.sqrt
---Used internally. Creates a CollapsedModel from a Model and also returns the biggest distance from its origin (for frustum culling)
---@param model Model
---@return CollapsedModel
---@return number biggestDistance largest distance of a vertex in the model from its origin
function loadModelRaw(model)
	---@class CollapsedModel
	local transformedModel = {}
	local biggestDistance = 0

	for i = 1, #model do
		local polygon = model[i]
		transformedModel[#transformedModel+1] = {}
		transformedModel[#transformedModel][1] = polygon.x1
		transformedModel[#transformedModel][2] = polygon.y1
		transformedModel[#transformedModel][3] = polygon.z1
		transformedModel[#transformedModel][4] = polygon.x2
		transformedModel[#transformedModel][5] = polygon.y2
		transformedModel[#transformedModel][6] = polygon.z2
		transformedModel[#transformedModel][7] = polygon.x3
		transformedModel[#transformedModel][8] = polygon.y3
		transformedModel[#transformedModel][9] = polygon.z3
		transformedModel[#transformedModel][10] = polygon.forceRender
		transformedModel[#transformedModel][11] = polygon.c
		transformedModel[#transformedModel][12] = polygon.char
		transformedModel[#transformedModel][13] = polygon.charc
		transformedModel[#transformedModel][14] = polygon.outlineColor
		transformedModel[#transformedModel][15] = i

		local d1 = sqrt(polygon.x1*polygon.x1 + polygon.y1*polygon.y1 + polygon.z1*polygon.z1)
		local d2 = sqrt(polygon.x2*polygon.x2 + polygon.y2*polygon.y2 + polygon.z2*polygon.z2)
		local d3 = sqrt(polygon.x3*polygon.x3 + polygon.y3*polygon.y3 + polygon.z3*polygon.z3)

		if d1 > biggestDistance then
			biggestDistance = d1
		end
		if d2 > biggestDistance then
			biggestDistance = d2
		end
		if d3 > biggestDistance then
			biggestDistance = d3
		end
	end
	return transformedModel, biggestDistance
end

---@param path string
function loadModel(path)
	local modelFile = fs.open(path, "r")
	if not modelFile then
		error("Could not find model for an object at path: " .. path)
	end
	local content = modelFile.readAll()
	modelFile.close()

	---@class Model
	---@field invertTriangles fun(self: Model): Model Inverts the direction of all triangles
	---@field setOutline fun(self: Model, col: number|table): Model Change the outline colors of polygons in a Model. If number, will set the outline color for each Polygon, if table, uses it as a mapping from Polygon color to new outline color
	---@field mapColor fun(self: Model, col: number|table): Model Change the colors of polygons in a Model. If number, will set the color for each Polygon, if table, uses it as a mapping from Polygon color to new the new color
	---@field center fun(self: Model): Model Center the Model such that the origin is in the middle of the bounding box
	---@field normalizeScale fun(self: Model): Model Rescales the model such that the largest value of any coordinate is equal to 1
	---@field normalizeScaleY fun(self: Model): Model Similar to normalizeScale, rescales the model, but only uses the y coordinate to determine how much it is scaled (normalizes height)
	---@field scale fun(self: Model, scale: number): Model Scales the model
	---@field translate fun(self: Model, dx: number?, dy: number?, dz: number?): Model Translates the model
	---@field rotate fun(self: Model, rotX: number?, rotY: number?, rotZ: number?): Model Rotates a given Model around three axes (radians)
	---@field alignBottom fun(self: Model): Model Translates the model such that the bottom aligns with y = 0
	---@field decimate fun(self: Model, quality: number, mode?: "ratio"|"polys"): Model Triangle decimation (reduce the quality / number of polygons in a model)
	---@field toLoD fun(self: Model, settings: {minQuality: number?, variantCount: number?, qualityHalvingDistance: number?, quickInitWorseRuntime: boolean?}?): LoDModel Create a new Level of Detail Model
	local model = textutils.unserialise(content)

	for name, func in pairs(transforms) do
		model[name] = func
	end

	return model
end

local pi = math.pi

local sin = math.sin
local cos = math.cos
local tan = math.tan
local sqrt = math.sqrt

---Creates a new ThreeDFrame
---@param x1 number? top-left x coordinate of the ThreeDFrame on the screen
---@param y1 number? top-left y coordinate of the ThreeDFrame on the screen
---@param x2 number? bottom-right x coordinate of the ThreeDFrame on the screen
---@param y2 number? bottom-right y coordinate of the ThreeDFrame on the screen
---@return ThreeDFrame
local function newFrame(x1, y1, x2, y2)
	local width, height = term.getSize()
	if x1 and x2 then
		width = x2 - x1 + 1
	end
	if y1 and y2 then
		height = y2 - y1 + 1
	end

	local x1 = x1 or 1
	local y1 = y1 or 1
	local x2 = x2 or (width - x1 + 1)
	local y2 = y2 or (height - y1 + 1)

	---@class ThreeDFrame
	local frame = {
		---@class CollapsedCamera
		camera = {
			0.000001,
			0.000001,
			0.000001,
			nil,
			0,
			0,
		},
		buffer = newBuffer(x1, y1, x2, y2),
		x1 = x1,
		y1 = y1,
		x2 = x2,
		y2 = y2,
		width = width,
		height = height,
		blittleOn = false,
		pixelratio = 1.5,
	}
	frame.FoV = 90
	frame.camera[7] = rad(frame.FoV)
	frame.t = tan(rad(frame.FoV / 2)) * 2 * 0.0001

	local renderOffsetX, renderOffsetY, sXFactor, sYFactor

	function frame:setBackgroundColor(c)
		local buff = self.buffer
		buff.backgroundColor = c
		buff:fastClear()
	end

	local function updateMappingConstants()
		renderOffsetX = floor(frame.width * 0.5) + 1
		renderOffsetY = floor(frame.height * 0.5)

		sXFactor = 0.0001 * frame.width / frame.t
		sYFactor = -0.0001 * frame.width / (frame.t * frame.height * frame.pixelratio) * frame.height
	end

	function frame:setSize(x1, y1, x2, y2)
		self.x1 = x1
		self.y1 = y1
		self.x2 = x2
		self.y2 = y2

		if not self.blittleOn then
			self.buffer:setBufferSize(x1, y1, x2, y2)
			self.width = x2 - x1 + 1
			self.height = y2 - y1 + 1
			self.pixelratio = 1.5
		else
			self.width = (x2 - x1 + 1) * 2
			self.height = (y2 - y1 + 1) * 3
			self.pixelratio = 1
			self.buffer:setBufferSize(x1, y1, x1 + self.width - 1, y1 + self.height - 1)
		end
		updateMappingConstants()
	end

	---If enabled, uses special characters to achieve a higher perceived resolution (enabled by default)
	---@param enabled boolean
	function frame:highResMode(enabled)
		self.blittleOn = enabled
		self.buffer:highResMode(enabled)
		if enabled then
			self.width = (self.x2 - self.x1 + 1) * 2
			self.height = (self.y2 - self.y1 + 1) * 3
			self.buffer:setBufferSize(self.x1, self.y1, self.x1 + self.width - 1, self.y1 + self.height - 1)
			self.pixelratio = 1
		else
			self.buffer:setBufferSize(self.x1, self.y1, self.x2, self.y2)
			self.width = self.x2 - self.x1 + 1
			self.height = self.y2 - self.y1 + 1
			self.pixelratio = 1.5
		end
		updateMappingConstants()
	end

	function frame:map3dTo2d(x, y, z)
		local camera = self.camera
		local cA1 = sin(camera[4] or 0)
		local cA2 = cos(camera[4] or 0)
		local cA3 = sin(-camera[5])
		local cA4 = cos(-camera[5])
		local cA5 = sin(camera[6])
		local cA6 = cos(camera[6])

		local dX = x - camera[1]
		local dY = y - camera[2]
		local dZ = z - camera[3]

		local dX2 = cA4 * dX - cA3 * dZ
		dZ = cA3 * dX + cA4 * dZ
		dX = dX2

		local dY2 = cA6 * dY - cA5 * dX
		dX = cA5 * dY + cA6 * dX
		dY = dY2

		if cA1 ~= 0 then
			local dZ2 = cA1 * dZ - cA2 * dY
			dY = cA2 * dZ + cA1 * dY
			dZ = dZ2
		end

		local sX = (dZ / dX) * sXFactor + renderOffsetX
		local sY = (dY / dX) * sYFactor + renderOffsetY

		return sX, sY, dX >= 0.0001
	end

	---Draw an object
	---@param object PineObject
	---@param camera CollapsedCamera
	---@param cameraAngles CameraAngles
	function frame:drawObject(object, camera, cameraAngles)
		local oX = object[1]
		local oY = object[2]
		local oZ = object[3]

		local cA1 = cameraAngles[1]
		local cA2 = cameraAngles[2]
		local cA3 = cameraAngles[3]
		local cA4 = cameraAngles[4]
		local cA5 = cameraAngles[5]
		local cA6 = cameraAngles[6]

		local xCameraOffset = oX and (oX - camera[1]) or 0
		local yCameraOffset = oY and (oY - camera[2]) or 0
		local zCameraOffset = oZ and (oZ - camera[3]) or 0

		local LoDModel = object[9]
		if LoDModel then
			LoDModel:update(object, camera)
		end

		local model = object[7]
		if #model <= 0 then
			return
		end
		local modelSize = object[8]

		local dX = xCameraOffset
		local dY = yCameraOffset
		local dZ = zCameraOffset

		local dX2 = cA4 * dX - cA3 * dZ
		local dZ = cA3 * dX + cA4 * dZ
		local dX = dX2

		--local dY2 = cA6 * dY - cA5 * dX
		local dX = cA5 * dY + cA6 * dX
		--dY = dY2

		if dX < -modelSize then
			return
		end

		local FoV = 0.5*camera[7]
		local dotX = sin(FoV)
		local dotZ = cos(FoV)

		if (dX + modelSize)*dotX + (dZ + modelSize)*dotZ < 0 then
			return
		end
		if (dX + modelSize)*dotX - (dZ - modelSize)*dotZ < 0 then
			return
		end

		local rotX = object[4]
		local rotY = object[5]
		local rotZ = object[6]
		if (rotX and rotX ~= 0) or (rotY and rotY ~= 0) or (rotZ and rotZ ~= 0) then
			model = rotateCollapsedModel(model, rotX, rotY, rotZ)
		end
		sortPolygons(model, oX, oY, oZ, camera)

		local clippingEnabled = xCameraOffset*xCameraOffset + yCameraOffset*yCameraOffset + zCameraOffset*zCameraOffset < modelSize*modelSize*4

		local renderOffsetX = renderOffsetX
		local renderOffsetY = renderOffsetY

		local sXFactor = sXFactor
		local sYFactor = sYFactor

		local cA1 = cA1
		local cA2 = cA2
		local cA3 = cA3
		local cA4 = cA4
		local cA5 = cA5
		local cA6 = cA6

		local xCameraOffset = xCameraOffset
		local yCameraOffset = yCameraOffset
		local zCameraOffset = zCameraOffset

		local function map3dTo2d(dX, dY, dZ)
			local dX2 = cA4 * dX - cA3 * dZ
			dZ = cA3 * dX + cA4 * dZ
			dX = dX2

			local dY2 = cA6 * dY - cA5 * dX
			dX = cA5 * dY + cA6 * dX
			dY = dY2

			local sX = (dZ / dX) * sXFactor + renderOffsetX
			local sY = (dY / dX) * sYFactor + renderOffsetY

			return sX, sY, dX
		end

		if cA1 ~= 0 then
			function map3dTo2d(dX, dY, dZ)
				local dX2 = cA4 * dX - cA3 * dZ
				dZ = cA3 * dX + cA4 * dZ
				dX = dX2

				local dY2 = cA6 * dY - cA5 * dX
				dX = cA5 * dY + cA6 * dX
				dY = dY2

				local dZ2 = cA1 * dZ - cA2 * dY
				dY = cA2 * dZ + cA1 * dY
				dZ = dZ2

				local sX = (dZ / dX) * sXFactor + renderOffsetX
				local sY = (dY / dX) * sYFactor + renderOffsetY

				return sX, sY, dX
			end
		end

		local sortedPolygons = model
		local buff = self.buffer
		for i = 1, #sortedPolygons do
			local polygon = sortedPolygons[i]

			local x1, y1, dX1 = map3dTo2d(polygon[1] + xCameraOffset, polygon[2] + yCameraOffset, polygon[3] + zCameraOffset)
			if dX1 > 0.00010000001 then
				local x2, y2, dX2 = map3dTo2d(polygon[4] + xCameraOffset, polygon[5] + yCameraOffset, polygon[6] + zCameraOffset)
				if dX2 > 0.00010000001 then
					local x3, y3, dX3 = map3dTo2d(polygon[7] + xCameraOffset, polygon[8] + yCameraOffset, polygon[9] + zCameraOffset)
					if dX3 > 0.00010000001 then
						if polygon[10] or (x2 - x1) * (y3 - y2) - (y2 - y1) * (x3 - x2) < 0 then
							buff:drawTriangle(x1, y1, x2, y2, x3, y3, polygon[11], polygon[12], polygon[13], polygon[14])
						end
					elseif clippingEnabled then
						local function map3dTo2dFull(x, y, z)
							local dX = x + xCameraOffset
							local dY = y + yCameraOffset
							local dZ = z + zCameraOffset

							local dX2 = cA4 * dX - cA3 * dZ
							dZ = cA3 * dX + cA4 * dZ
							dX = dX2

							local dY2 = cA6 * dY - cA5 * dX
							dX = cA5 * dY + cA6 * dX
							dY = dY2

							if cA1 ~= 0 then
								local dZ2 = cA1 * dZ - cA2 * dY
								dY = cA2 * dZ + cA1 * dY
								dZ = dZ2
							end

							local sX = (dZ / dX) * sXFactor + renderOffsetX
							local sY = (dY / dX) * sYFactor + renderOffsetY

							return sX, sY, dX, dY, dZ
						end

						local x1, y1, dX1, dY1, dZ1 = map3dTo2dFull(polygon[1], polygon[2], polygon[3])
						local x2, y2, dX2, dY2, dZ2 = map3dTo2dFull(polygon[4], polygon[5], polygon[6])
						local x3, y3, dX3, dY3, dZ3 = map3dTo2dFull(polygon[7], polygon[8], polygon[9])

						local abs = math.abs

						-- 1, 1, 0

						local w3 = abs(dX3 - 0.0001)
						local w1 = abs(dX1 - 0.0001)
						local wT = w1 + w3
						local newPosAZ = (dZ3 * w1 + dZ1 * w3) / wT
						local newPosAY = (dY3 * w1 + dY1 * w3) / wT

						local renderOffsetX, sXFactor, renderOffsetY, sYFactor = renderOffsetX, sXFactor, renderOffsetY, sYFactor
						local AX = (newPosAZ * 10000) * sXFactor + renderOffsetX
						local AY = (newPosAY * 10000) * sYFactor + renderOffsetY

						if polygon[10] or (x2 - x1) * (AY - y2) - (y2 - y1) * (AX - x2) < 0 then
							buff:drawTriangle(x1, y1, x2, y2, AX, AY, polygon[11], polygon[12], polygon[13], polygon[14])

							local w2 = abs(dX2 - 0.0001)
							local wT = w2 + w3
							local newPosAZ = (dZ2 * w3 + dZ3 * w2) / wT
							local newPosAY = (dY2 * w3 + dY3 * w2) / wT

							local BX = (newPosAZ * 10000) * sXFactor + renderOffsetX
							local BY = (newPosAY * 10000) * sYFactor + renderOffsetY
							buff:drawTriangle(BX, BY, x2, y2, AX, AY, polygon[11], polygon[12], polygon[13], polygon[14])
						end
					end
				elseif clippingEnabled then
					local function map3dTo2dFull(x, y, z)
						local dX = x + xCameraOffset
						local dY = y + yCameraOffset
						local dZ = z + zCameraOffset

						local dX2 = cA4 * dX - cA3 * dZ
						dZ = cA3 * dX + cA4 * dZ
						dX = dX2

						local dY2 = cA6 * dY - cA5 * dX
						dX = cA5 * dY + cA6 * dX
						dY = dY2

						if cA1 ~= 0 then
							local dZ2 = cA1 * dZ - cA2 * dY
							dY = cA2 * dZ + cA1 * dY
							dZ = dZ2
						end

						local sX = (dZ / dX) * sXFactor + renderOffsetX
						local sY = (dY / dX) * sYFactor + renderOffsetY

						return sX, sY, dX, dY, dZ
					end

					local x1, y1, dX1, dY1, dZ1 = map3dTo2dFull(polygon[1], polygon[2], polygon[3])
					local x2, y2, dX2, dY2, dZ2 = map3dTo2dFull(polygon[4], polygon[5], polygon[6])
					local x3, y3, dX3, dY3, dZ3 = map3dTo2dFull(polygon[7], polygon[8], polygon[9])

					local abs = math.abs

					if dX3 > 0.00010000001 then
						-- 1 0 1

						local w2 = abs(dX2 - 0.0001)
						local w1 = abs(dX1 - 0.0001)
						local wT = w1 + w2
						local newPosAZ = (dZ2 * w1 + dZ1 * w2) / wT
						local newPosAY = (dY2 * w1 + dY1 * w2) / wT

						local renderOffsetX, sXFactor, renderOffsetY, sYFactor = renderOffsetX, sXFactor, renderOffsetY, sYFactor
						local AX = (newPosAZ * 10000) * sXFactor + renderOffsetX
						local AY = (newPosAY * 10000) * sYFactor + renderOffsetY

						if polygon[10] or (AX - x1) * (y3 - AY) - (AY - y1) * (x3 - AX) < 0 then
							buff:drawTriangle(x1, y1, AX, AY, x3, y3, polygon[11], polygon[12], polygon[13], polygon[14])

							local w3 = abs(dX3 - 0.0001)
							local wT = w2 + w3
							local newPosAZ = (dZ2 * w3 + dZ3 * w2) / wT
							local newPosAY = (dY2 * w3 + dY3 * w2) / wT

							local BX = (newPosAZ * 10000) * sXFactor + renderOffsetX
							local BY = (newPosAY * 10000) * sYFactor + renderOffsetY
							buff:drawTriangle(BX, BY, AX, AY, x3, y3, polygon[11], polygon[12], polygon[13], polygon[14])
						end
					else
						-- 1 0 0

						local w1 = abs(dX1 - 0.0001)
						local w2 = abs(dX2 - 0.0001)
						local w3 = abs(dX3 - 0.0001)
						local wTA = w1 + w2
						local wTB = w1 + w3

						local newPosAZ = (dZ1 * w2 + dZ2 * w1) / wTA
						local newPosAY = (dY1 * w2 + dY2 * w1) / wTA
						local renderOffsetX, sXFactor, renderOffsetY, sYFactor = renderOffsetX, sXFactor, renderOffsetY, sYFactor
						local AX = (newPosAZ * 10000) * sXFactor + renderOffsetX
						local AY = (newPosAY * 10000) * sYFactor + renderOffsetY

						local newPosBZ = (dZ1 * w3 + dZ3 * w1) / wTB
						local newPosBY = (dY1 * w3 + dY3 * w1) / wTB
						local BX = (newPosBZ * 10000) * sXFactor + renderOffsetX
						local BY = (newPosBY * 10000) * sYFactor + renderOffsetY

						if polygon[10] or (AX - x1) * (BY - AY) - (AY - y1) * (BX - AX) < 0 then
							buff:drawTriangle(x1, y1, AX, AY, BX, BY, polygon[11], polygon[12], polygon[13], polygon[14])
						end
					end
				end
			elseif clippingEnabled then
				local function map3dTo2dFull(x, y, z)
					local dX = x + xCameraOffset
					local dY = y + yCameraOffset
					local dZ = z + zCameraOffset

					local dX2 = cA4 * dX - cA3 * dZ
					dZ = cA3 * dX + cA4 * dZ
					dX = dX2

					local dY2 = cA6 * dY - cA5 * dX
					dX = cA5 * dY + cA6 * dX
					dY = dY2

					if cA1 ~= 0 then
						local dZ2 = cA1 * dZ - cA2 * dY
						dY = cA2 * dZ + cA1 * dY
						dZ = dZ2
					end

					local sX = (dZ / dX) * sXFactor + renderOffsetX
					local sY = (dY / dX) * sYFactor + renderOffsetY

					return sX, sY, dX, dY, dZ
				end

				local x1, y1, dX1, dY1, dZ1 = map3dTo2dFull(polygon[1], polygon[2], polygon[3])
				local x2, y2, dX2, dY2, dZ2 = map3dTo2dFull(polygon[4], polygon[5], polygon[6])
				local x3, y3, dX3, dY3, dZ3 = map3dTo2dFull(polygon[7], polygon[8], polygon[9])

				local abs = math.abs

				if dX2 > 0.00010000001 then
					if dX3 > 0.00010000001 then
						-- 0 1 1

						local w1 = abs(dX1 - 0.0001)
						local w2 = abs(dX2 - 0.0001)
						local wT = w1 + w2
						local newPosAZ = (dZ1 * w2 + dZ2 * w1) / wT
						local newPosAY = (dY1 * w2 + dY2 * w1) / wT

						local renderOffsetX, sXFactor, renderOffsetY, sYFactor = renderOffsetX, sXFactor, renderOffsetY, sYFactor
						local AX = (newPosAZ * 10000) * sXFactor + renderOffsetX
						local AY = (newPosAY * 10000) * sYFactor + renderOffsetY
						if polygon[10] or (x2 - AX) * (y3 - y2) - (y2 - AY) * (x3 - x2) < 0 then
							buff:drawTriangle(AX, AY, x2, y2, x3, y3, polygon[11], polygon[12], polygon[13], polygon[14])

							local w3 = abs(dX3 - 0.0001)
							local wT = w1 + w3
							local newPosAZ = (dZ1 * w3 + dZ3 * w1) / wT
							local newPosAY = (dY1 * w3 + dY3 * w1) / wT

							local BX = (newPosAZ * 10000) * sXFactor + renderOffsetX
							local BY = (newPosAY * 10000) * sYFactor + renderOffsetY
							buff:drawTriangle(AX, AY, BX, BY, x3, y3, polygon[11], polygon[12], polygon[13], polygon[14])
						end
					else
						-- 0 1 0

						local w1 = abs(dX1 - 0.0001)
						local w2 = abs(dX2 - 0.0001)
						local w3 = abs(dX3 - 0.0001)
						local wTA = w2 + w1
						local wTB = w2 + w3

						local newPosAZ = (dZ1 * w2 + dZ2 * w1) / wTA
						local newPosAY = (dY1 * w2 + dY2 * w1) / wTA
						local renderOffsetX, sXFactor, renderOffsetY, sYFactor = renderOffsetX, sXFactor, renderOffsetY, sYFactor
						local AX = (newPosAZ * 10000) * sXFactor + renderOffsetX
						local AY = (newPosAY * 10000) * sYFactor + renderOffsetY

						local newPosBZ = (dZ2 * w3 + dZ3 * w2) / wTB
						local newPosBY = (dY2 * w3 + dY3 * w2) / wTB
						local BX = (newPosBZ * 10000) * sXFactor + renderOffsetX
						local BY = (newPosBY * 10000) * sYFactor + renderOffsetY

						if polygon[10] or (x2 - AX) * (BY - y2) - (y2 - AY) * (BX - x2) < 0 then
							buff:drawTriangle(AX, AY, x2, y2, BX, BY, polygon[11], polygon[12], polygon[13], polygon[14])
						end
					end
				else
					if dX3 > 0.00010000001 then
						-- 0 0 1

						local w1 = abs(dX1 - 0.0001)
						local w2 = abs(dX2 - 0.0001)
						local w3 = abs(dX3 - 0.0001)
						local wTA = w3 + w1
						local wTB = w3 + w2

						local newPosAZ = (dZ1 * w3 + dZ3 * w1) / wTA
						local newPosAY = (dY1 * w3 + dY3 * w1) / wTA
						local renderOffsetX, sXFactor, renderOffsetY, sYFactor = renderOffsetX, sXFactor, renderOffsetY, sYFactor
						local AX = (newPosAZ * 10000) * sXFactor + renderOffsetX
						local AY = (newPosAY * 10000) * sYFactor + renderOffsetY

						local newPosBZ = (dZ2 * w3 + dZ3 * w2) / wTB
						local newPosBY = (dY2 * w3 + dY3 * w2) / wTB
						local BX = (newPosBZ * 10000) * sXFactor + renderOffsetX
						local BY = (newPosBY * 10000) * sYFactor + renderOffsetY

						if polygon[10] or (BX - AX) * (y3 - BY) - (BY - AY) * (x3 - BX) < 0 then
							buff:drawTriangle(AX, AY, BX, BY, x3, y3, polygon[11], polygon[12], polygon[13], polygon[14])
						end
					--else
						-- 0 0 0
						-- (Don't draw anything)
					end
				end
			end
		end
	end

	---Draw objects and render them to the internal Buffer
	---@param objects PineObject[]
	function frame:drawObjects(objects)
		local camera = self.camera
		---@class CameraAngles
		local cameraAngles = {
			sin(camera[4] or 0), cos(camera[4] or 0),
			sin(-camera[5]), cos(-camera[5]),
			sin(camera[6]), cos(camera[6]),
		}

		sortObjects(objects, camera)
		local objects = objects
		for i = 1, #objects do
			self:drawObject(objects[i], camera, cameraAngles)
		end
	end

	function frame:drawBuffer()
		local buff = self.buffer
		buff:drawBuffer()
		buff:fastClear()
	end

	---@alias PineCamera {x: number?, y: number?, z: number?, rotX: number?, rotY: number?, rotZ: number?}

	---Update any position or rotation value of the Camera. You can also pass a PineCamera
	---@param cameraX number?
	---@param cameraY number?
	---@param cameraZ number?
	---@param rotX number?
	---@param rotY number?
	---@param rotZ number?
	---@overload fun(self, camera: PineCamera)
	function frame:setCamera(cameraX, cameraY, cameraZ, rotX, rotY, rotZ)
		local rad = math.rad
		if type(cameraX) == "table" then
			local camera = cameraX --[[@as PineCamera]]
			---@class CollapsedCamera
			self.camera = {
				camera.x or self.camera[1] or 0,
				camera.y or self.camera[2] or 0,
				camera.z or self.camera[3] or 0,
				camera.rotX and rad(camera.rotX + 90) or self.camera[4] or 0,
				camera.rotY and rad(camera.rotY) or self.camera[5] or 0,
				camera.rotZ and rad(camera.rotZ) or self.camera[6] or 0,
				self.camera[7],
			}
		else
			---@class CollapsedCamera
			self.camera = {
				cameraX or self.camera[1] or 0,
				cameraY or self.camera[2] or 0,
				cameraZ or self.camera[3] or 0,
				rotX and rad(rotX + 90) or self.camera[4] or 0,
				rotY and rad(rotY) or self.camera[5] or 0,
				rotZ and rad(rotZ) or self.camera[6] or 0,
				self.camera[7],
			}
		end
		if self.camera[4] == math.pi*0.5 then
			self.camera[4] = nil
		end
	end

	---Set the Field of View (degrees)
	---@param FoV number in degrees
	function frame:setFoV(FoV)
		self.FoV = FoV or 90
		self.t = tan(rad(self.FoV / 2)) * 2 * 0.0001
		updateMappingConstants()
		self.camera[7] = rad(self.FoV)
	end

	---If set to true, edges of triangles are colored differently to show the wireframe (useful for debugging)
	---@param enabled boolean
	function frame:setWireFrame(enabled)
		self.buffer:useTriangleEdges(enabled)
	end

	---Get closest object and polygon trace
	---@param objects PineObject[]
	---@param x number
	---@param y number
	---@return number|nil objectIndex index of a PineObject that was found at the given coordinates in the given table
	---@return number|nil polyIndex index of the Polygon in the Model of the PineObject if one was found
	function frame:getObjectIndexTrace(objects, x, y)
		local function sign(p1, p2, p3)
			return (p1.x - p3.x) * (p2.y - p3.y) - (p2.x - p3.x) * (p1.y - p3.y)
		end

		local function isInTriangle(checkX, checkY, x1, y1, x2, y2, x3, y3, framex1, framey1, framex2, framey2)
			local b1 = sign({x = checkX, y = checkY}, {x = x1, y = y1}, {x = x2, y = y2}) < 0
			local b2 = sign({x = checkX, y = checkY}, {x = x2, y = y2}, {x = x3, y = y3}) < 0
			local b3 = sign({x = checkX, y = checkY}, {x = x3, y = y3}, {x = x1, y = y1}) < 0

			return b1 == b2 and b2 == b3
		end

		local y = y - 1

		local solutions = {}
		if self.blittleOn then
			x = x * 2
			y = y * 3 + 1
		end

		local camera = self.camera

		---@class CameraAngles
		local cameraAngles = {
			sin(camera[4] or 0), cos(camera[4] or 0),
			sin(-camera[5]), cos(-camera[5]),
			sin(camera[6]), cos(camera[6]),
		}
		local cA1 = cameraAngles[1]
		local cA2 = cameraAngles[2]
		local cA3 = cameraAngles[3]
		local cA4 = cameraAngles[4]
		local cA5 = cameraAngles[5]
		local cA6 = cameraAngles[6]

		for i = 1, #objects do
			local object = objects[i]

			local model = object[7]

			local rotX = object[4]
			local rotY = object[5]
			local rotZ = object[6]
			if (rotX and rotX ~= 0) or (rotY and rotY ~= 0) or (rotZ and rotZ ~= 0) then
				model = rotateCollapsedModel(model, rotX, rotY, rotZ)
			end

			local oX = object[1]
			local oY = object[2]
			local oZ = object[3]

			local renderOffsetX = renderOffsetX
			local renderOffsetY = renderOffsetY

			local sXFactor = sXFactor
			local sYFactor = sYFactor

			local cA1 = cA1
			local cA2 = cA2
			local cA3 = cA3
			local cA4 = cA4
			local cA5 = cA5
			local cA6 = cA6

			local xCameraOffset = oX - camera[1]
			local yCameraOffset = oY - camera[2]
			local zCameraOffset = oZ - camera[3]

			local function map3dTo2d(x, y, z)
				local dX = x + xCameraOffset
				local dY = y + yCameraOffset
				local dZ = z + zCameraOffset

				local dX2 = cA4 * dX - cA3 * dZ
				dZ = cA3 * dX + cA4 * dZ
				dX = dX2

				local dY2 = cA6 * dY - cA5 * dX
				dX = cA5 * dY + cA6 * dX
				dY = dY2

				if cA1 ~= 0 then
					local dZ2 = cA1 * dZ - cA2 * dY
					dY = cA2 * dZ + cA1 * dY
					dZ = dZ2
				end

				local sX = (dZ / dX) * sXFactor + renderOffsetX
				local sY = (dY / dX) * sYFactor + renderOffsetY

				return sX, sY, dX > 0
			end

			for j = 1, #model do
				local polygon = model[j]

				local x1, y1, onScreen1 = map3dTo2d(polygon[1], polygon[2], polygon[3])
				if onScreen1 then
					local x2, y2, onScreen2 = map3dTo2d(polygon[4], polygon[5], polygon[6])
					if onScreen2 then
						local x3, y3, onScreen3 = map3dTo2d(polygon[7], polygon[8], polygon[9])
						if onScreen3 then
							if polygon[10] or (x2 - x1) * (y3 - y2) - (y2 - y1) * (x3 - x2) < 0 then
								if not self.blittleOn then
									if isInTriangle(x, y, x1, y1, x2, y2, x3, y3, self.x1, self.y1, self.x2, self.y2) then
										solutions[#solutions+1] = {objectIndex = i, polygonIndex = polygon[15]}
									end
								else
									if isInTriangle(x, y, x1, y1, x2, y2, x3, y3, (self.x2 - 1) * 2 + 1, (self.y1 - 1) * 3 + 1, (self.x2) * 2, (self.y2 + 1) * 3) then
										solutions[#solutions+1] = {objectIndex = i, polygonIndex = polygon[15]}
									end
								end
							end
						end
					end
				end
			end
		end

		if #solutions <= 0 then
			return
		elseif #solutions == 1 then
			return solutions[1].objectIndex, solutions[1].polygonIndex
		end

		local objectSolution = {}

		local closestObject = -1
		local closestObjectDistance = math.huge
		for i = 1, #solutions do
			local object = objects[solutions[i].objectIndex]

			local dX = camera[1] - object[1]
			local dY = camera[2] - object[2]
			local dZ = camera[3] - object[3]
			local distance = sqrt(dX*dX + dY*dY + dZ*dZ)

			if distance < closestObjectDistance then
				closestObjectDistance = distance
				closestObject = solutions[i].objectIndex
			end
		end
		for i = 1, #solutions do
			local object = objects[solutions[i].objectIndex]

			local dX = camera[1] - object[1]
			local dY = camera[2] - object[2]
			local dZ = camera[3] - object[3]
			local distance = sqrt(dX*dX + dY*dY + dZ*dZ)

			if distance == closestObjectDistance then
				objectSolution[#objectSolution+1] = solutions[i].polygonIndex
			end
		end

		local object = objects[closestObject]

		local model = object[7]

		local closestPolygon = -1
		local closestPolygonDistance = math.huge

		local rx = object[1] - camera[1]
		local ry = object[2] - camera[2]
		local rz = object[3] - camera[3]

		for i = 1, #objectSolution do
			local polygonI = objectSolution[i]
			local polygon = model[polygonI]

			local avgX = rx + (polygon[1] + polygon[4] + polygon[7]) / 3
			local avgY = ry + (polygon[2] + polygon[5] + polygon[8]) / 3
			local avgZ = rz + (polygon[3] + polygon[6] + polygon[9]) / 3

			local distance = sqrt(avgX*avgX + avgY*avgY + avgZ*avgZ)

			if distance < closestPolygonDistance then
				closestPolygonDistance = distance
				closestPolygon = objectSolution[i]
			end
		end

		return closestObject, closestPolygon
	end

	---Creates a new PineObject
	---@param model string|Model|LoDModel either a string (path to the model file) or Model or LoDModel
	---@param x number?
	---@param y number?
	---@param z number?
	---@param rotX number?
	---@param rotY number?
	---@param rotZ number?
	---@return PineObject
	function frame:newObject(model, x, y, z, rotX, rotY, rotZ)
		local objModel = nil
		local modelSize = nil

		if type(model) == "table" then
			if model.initObject then
				-- @cast model LoDModel
				-- objModel, modelSize = loadModelRaw(model)
				-- model:initObject(object)
			else
				---@cast model Model
				objModel, modelSize = loadModelRaw(model)
			end
		else
			---@cast model string
			local modelRaw = loadModel(model)
			objModel, modelSize = loadModelRaw(modelRaw)
		end

		---@class PineObject
		local object = {
			x, y, z,
			rotX, rotY, rotZ,
			objModel, modelSize,
		}
		object.frame = self

		---Set the object's position
		---@param newX number?
		---@param newY number?
		---@param newZ number?
		function object:setPos(newX, newY, newZ)
			self[1] = newX or self[1]
			self[2] = newY or self[2]
			self[3] = newZ or self[3]
		end

		---Set the object's rotation
		---@param newRotX number?
		---@param newRotY number?
		---@param newRotZ number?
		function object:setRot(newRotX, newRotY, newRotZ)
			self[4] = newRotX or self[4]
			self[5] = newRotY or self[5]
			self[6] = newRotZ or self[6]
		end

		---Set the object's position
		---@param ref string|Model either a string (path to the model file) or Model
		function object:setModel(ref)
			if type(ref) == "table" then
				---@cast ref Model
				objModel, modelSize = loadModelRaw(ref)
				self[7] = objModel
				self[8] = modelSize
			else
				---@cast ref string
				local modelRaw = loadModel(ref)
				objModel, modelSize = loadModelRaw(modelRaw)
				self[7] = objModel
				self[8] = modelSize
			end
		end

		if type(model) == "table" then
			if model.initObject then
				---@cast model LoDModel
				model:initObject(object)
			end
		end

		return object
	end

	updateMappingConstants()
	frame:highResMode(true)

	return frame
end

local models = {}
local function newPoly(x1, y1, z1, x2, y2, z2, x3, y3, z3, c)
	---@class Polygon
	local poly = {
		x1 = x1, y1 = y1, z1 = z1, x2 = x2, y2 = y2, z2 = z2, x3 = x3, y3 = y3, z3 = z3,
		c = c,
	}
	return poly
end

---@param options {color: number?, top: number?, side: number?, side2: number?, bottom: number?, bottom2: number?}
function models:cube(options)
	options.color = options.color or colors.red
	---@class Model
	local cube = {
		newPoly(-.5,-.5,-.5, .5,-.5,.5, -.5,-.5,.5, options.bottom or options.color),
		newPoly(-.5,-.5,-.5, .5,-.5,-.5, .5,-.5,.5, options.bottom2 or options.bottom or options.color),
		newPoly(-.5,.5,-.5, -.5,.5,.5, .5,.5,.5, options.top or options.color),
		newPoly(-.5,.5,-.5, .5,.5,.5, .5,.5,-.5, options.top or options.color),
		newPoly(-.5,-.5,-.5, -.5,-.5,.5, -.5,.5,-.5, options.side or options.color),
		newPoly(-.5,-.5,.5, -.5,.5,.5, -.5,.5,-.5, options.side2 or options.side or options.color),
		newPoly(.5,-.5,-.5, .5,.5,.5, .5,-.5,.5, options.side or options.color),
		newPoly(.5,-.5,-.5, .5,.5,-.5, .5,.5,.5, options.side2 or options.side or options.color),
		newPoly(-.5,-.5,-.5, .5,.5,-.5, .5,-.5,-.5, options.side or options.color),
		newPoly(-.5,-.5,-.5, -.5,.5,-.5, .5,.5,-.5, options.side2 or options.side or options.color),
		newPoly(-.5,-.5,.5, .5,-.5,.5, -.5,.5,.5, options.side or options.color),
		newPoly(.5,-.5,.5, .5,.5,.5, -.5,.5,.5, options.side2 or options.side or options.color),
	}
	return cube
end

---@param options {res: number?, color: number?, color2: number?, colors: number?, top: number?, bottom: number?}
function models:sphere(options)
	options.res = options.res or 32
	options.color = options.color or colors.red
	---@class Model
	local model = {}
	local prevPoints = {}
	for i = 0, options.res do
		local y = 0.5*cos(i/options.res*pi)
		local newPrevPoints = {}
		for j = 0, options.res do
			local radius = 0.5 * sqrt(1 - (y*2)*(y*2))
			local x = cos(j/options.res*pi*2) * radius
			local z = sin(j/options.res*pi*2) * radius
			local x2 = cos((j+1)/options.res*pi*2) * radius
			local z2 = sin((j+1)/options.res*pi*2) * radius
			if (prevPoints[j]) then
				model[#model+1] = {
					x1 = prevPoints[(j+1) % options.res].x,
					y1 = prevPoints[(j+1) % options.res].y,
					z1 = prevPoints[(j+1) % options.res].z,
					x2 = x,
					y2 = y,
					z2 = z,
					x3 = prevPoints[j].x,
					y3 = prevPoints[j].y,
					z3 = prevPoints[j].z,
					c = options.color,
				}
				model[#model+1] = {
					x1 = x2,
					y1 = y,
					z1 = z2,
					x2 = x,
					y2 = y,
					z2 = z,
					x3 = prevPoints[(j+1) % options.res].x,
					y3 = prevPoints[(j+1) % options.res].y,
					z3 = prevPoints[(j+1) % options.res].z,
					c = options.color2 or options.color,
				}
			end

			newPrevPoints[j] = {x = x, y = y, z = z}
		end
		prevPoints = newPrevPoints
	end

	if options.colors or options.top or options.bottom then
		for i = 1, #model do
			local poly = model[i]
			local avgY = (poly.y1 + poly.y2 + poly.y3) / 3
			if options.colors then
				local index = floor((-avgY + 0.5) * (#options.colors)+1)
				poly.c = options.colors[index] or poly.c
			else
				if avgY >= 0 then
					poly.c = options.top or poly.c
				else
					poly.c = options.bottom or poly.c
				end
			end
		end
	end

	return model
end
---@param options {res: number?, color: number?, color2: number?, colors: number?, top: number?, bottom: number?, colorsFractal: boolean?}
function models:icosphere(options)
	options.res = options.res or 1

	local phi = (1 + sqrt(5))/2
	local v = {
		{phi, 1, 0},
		{phi, -1, 0},
		{-phi, -1, 0},
		{-phi, 1, 0},
		{1, 0, phi},
		{-1, 0, phi},
		{-1, 0, -phi},
		{1, 0, -phi},
		{0, phi, 1},
		{0, phi, -1},
		{0, -phi, -1},
		{0, -phi, 1},
	}

	local function buildPoly(i1, i2, i3)
		return newPoly(v[i1][1], v[i1][2], v[i1][3], v[i2][1], v[i2][2], v[i2][3], v[i3][1], v[i3][2], v[i3][3], options.colors and 1 or options.color)
	end

	---@class Model
	local model = {
		buildPoly(11, 2, 12),
		buildPoly(11, 8, 2),
		buildPoly(11, 7, 8),
		buildPoly(11, 3, 7),
		buildPoly(11, 12, 3),

		buildPoly(4, 7, 3),
		buildPoly(4, 10, 7),
		buildPoly(4, 9, 10),
		buildPoly(4, 6, 9),
		buildPoly(4, 3, 6),

		buildPoly(5, 6, 12),
		buildPoly(5, 9, 6),
		buildPoly(5, 1, 9),
		buildPoly(5, 2, 1),
		buildPoly(5, 12, 2),

		buildPoly(3, 12, 6),
		buildPoly(1, 8, 10),
		buildPoly(1, 10, 9),
		buildPoly(1, 2, 8),
		buildPoly(10, 8, 7),
	}

	local function subdivide()
		local newModel = {}
		for i = 1, #model do
			local poly = model[i]

			local AB = {
				x = (poly.x1 + poly.x2)/2,
				y = (poly.y1 + poly.y2)/2,
				z = (poly.z1 + poly.z2)/2,
			}
			local AC = {
				x = (poly.x1 + poly.x3)/2,
				y = (poly.y1 + poly.y3)/2,
				z = (poly.z1 + poly.z3)/2,
			}
			local BC = {
				x = (poly.x2 + poly.x3)/2,
				y = (poly.y2 + poly.y3)/2,
				z = (poly.z2 + poly.z3)/2,
			}

			local nextColor = poly.c
			if options.colorsFractal then
				nextColor = (nextColor % #options.colors) + 1
			end

			newModel[#newModel+1] = newPoly(AB.x, AB.y, AB.z, BC.x, BC.y, BC.z, AC.x, AC.y, AC.z, poly.c)
			newModel[#newModel+1] = newPoly(poly.x1, poly.y1, poly.z1, AB.x, AB.y, AB.z, AC.x, AC.y, AC.z, nextColor)
			newModel[#newModel+1] = newPoly(AB.x, AB.y, AB.z, poly.x2, poly.y2, poly.z2, BC.x, BC.y, BC.z, nextColor)
			newModel[#newModel+1] = newPoly(AC.x, AC.y, AC.z, BC.x, BC.y, BC.z, poly.x3, poly.y3, poly.z3, nextColor)
		end
		model = newModel
	end

	for i = 1, options.res-1 do
		subdivide()
	end

	local function forceLength(x, y, z)
		local length = math.sqrt(x*x + y*y + z*z)
		local ratio = 0.5 / length
		return x*ratio, y*ratio, z*ratio
	end

	for i = 1, #model do
		local poly = model[i]
		poly.x1, poly.y1, poly.z1 = forceLength(poly.x1, poly.y1, poly.z1)
		poly.x2, poly.y2, poly.z2 = forceLength(poly.x2, poly.y2, poly.z2)
		poly.x3, poly.y3, poly.z3 = forceLength(poly.x3, poly.y3, poly.z3)
		if not options.colorsFractal then
			local avgY = (poly.y1 + poly.y2 + poly.y3) / 3
			if (options.colors) then
				local index = math.floor((-avgY + 0.5) * (#options.colors)+1)
				poly.c = options.colors[index] or poly.c
			else
				if (avgY >= 0) then
					poly.c = options.top or poly.c
				else
					poly.c = options.bottom or poly.c
				end
			end
		else
			poly.c = options.colors[poly.c]
		end
	end

	return model
end
---@param options {size: number?, color: number?, y: number?}
function models:plane(options)
	options.color = options.color or colors.lime
	options.size = options.size or 1
	options.y = options.y or 0
	---@class Model
	local plane = {
		newPoly(-1 * options.size, options.y, 1 * options.size, 1 * options.size, options.y, -1 * options.size, -1 * options.size, options.y, -1 * options.size, options.color),
		newPoly(-1 * options.size, options.y, 1 * options.size, 1 * options.size, options.y, 1 * options.size, 1 * options.size, options.y, -1 * options.size, options.color),
	}
	return plane
end
---@param options {res: number?, randomOffset: number?, height: number?, randomHeight: number?, y: number?, scale: number?, color: number?, snowColor: number?, snow: number?, snowHeight: number?}
function models:mountains(options)
	options.res = options.res or 20
	options.randomOffset = options.randomOffset or 0
	options.height = options.height or 1
	options.randomHeight = options.randomHeight or 0
	options.y = options.y or 0
	options.scale = options.scale or 100
	options.color = options.color or colors.green
	options.snowColor = options.snowColor or colors.white

	local minHeight = 3/options.res * options.height / (options.randomHeight + 1)
	local maxHeight = 3/options.res * options.height * (options.randomHeight + 1)

	---@class Model
	local model = {}
	for i = 0, options.res do
		local offset = math.random(-options.randomOffset*100, options.randomOffset*100)/100
		local pos = i + offset
		local x1 = cos((pos-1)  /options.res*pi*2) * options.scale
		local z1 = sin((pos-1)  /options.res*pi*2) * options.scale
		local x2 = cos((pos-0.5)/options.res*pi*2) * options.scale
		local z2 = sin((pos-0.5)/options.res*pi*2) * options.scale
		local x3 = cos(pos	  /options.res*pi*2) * options.scale
		local z3 = sin(pos	  /options.res*pi*2) * options.scale

		local mountainHeight = math.random(minHeight*100, maxHeight*100) / 100 * options.scale

		local polygon = {
			x1 = x1,
			y1 = options.y,
			z1 = z1,
			x2 = x3,
			y2 = options.y,
			z2 = z3,
			x3 = x2,
			y3 = options.y + mountainHeight,
			z3 = z2,
			c = options.color,
			forceRender = true,
		}
		model[#model+1] = polygon

		if options.snow then
			local snowDistance = 0.93
			local realSnowRatio = options.snowHeight or 0.5
			local snowRatio = 1 - (realSnowRatio * maxHeight) / (mountainHeight/options.scale)
			snowRatio = max(0, min(1, snowRatio))

			if snowRatio > 0.2 then
				local snowPolygon = {
					x1 = (x1*snowRatio + x2*(1-snowRatio)) * snowDistance,
					y1 = options.y + mountainHeight*(1-snowRatio),
					z1 = (z1*snowRatio + z2*(1-snowRatio)) * snowDistance,
					x2 = (x3*snowRatio + x2*(1-snowRatio)) * snowDistance,
					y2 = options.y + mountainHeight*(1-snowRatio),
					z2 = (z3*snowRatio + z2*(1-snowRatio)) * snowDistance,
					x3 = x2 * snowDistance,
					y3 = options.y + mountainHeight,
					z3 = z2 * snowDistance,
					c = options.snowColor,
					forceRender = true,
				}
				model[#model+1] = snowPolygon
			end
		end
	end
	return model
end

return {
	newFrame = newFrame,
	loadModel = loadModel,
	newBuffer = newBuffer,
	-- newLoDManager = newLoDManager,
	linear = linear,
	models = models,
	transforms = transforms,
}
