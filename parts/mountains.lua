
-- Made by Xella#8655

package.path = package.path .. ";/lib/?.lua"
local Pine3D = require("Pine3D")
local noise = require("noise")
local util = require("util")

local genOptions = {
	seed = 0,
	chunkRows = 2,
	chunkColumns = 2,
	maxHeight = 32,
	relativeSnowHeight = 0.70,
	relativeWaterHeight = 0.4,
	noiseSize = 32,
	terrainSmoothness = 3,
}

local speed = 9
local turnSpeed = 30
local time = tonumber(...)
local start = os.epoch "utc"

local camera = {
	x = 4.5,
	y = 8.75,
	z = -2.666,
	rotX = 0,
	rotY = 55,
	rotZ = -20,
}
local bank = 0

local ThreeDFrame = Pine3D.newFrame()
local highRes = true
ThreeDFrame:highResMode(highRes)

local function generateWorld(ThreeDFrame, genOptions)
	local seed = genOptions.seed
	local rows = genOptions.chunkRows
	local columns = genOptions.chunkColumns
	local maxHeight = genOptions.maxHeight
	local relativeSnowHeight = genOptions.relativeSnowHeight
	local relativeWaterHeight = genOptions.relativeWaterHeight
	local noiseSize = genOptions.noiseSize
	local terrainSmoothness = genOptions.terrainSmoothness

	local polyCount = 0
	local objects = {}

	local colors = colors
	local sqrt = math.sqrt
	local max = math.max

	math.randomseed(seed)
	for chunkX = 0, columns - 1 do
		for chunkZ = 0, rows - 1 do
			local mapNoise1 = noise.createNoise(noiseSize, chunkX, chunkZ, seed, terrainSmoothness)
			local mapNoise2 = noise.createNoise(noiseSize, chunkX + 1, chunkZ, seed, terrainSmoothness)
			local mapNoise3 = noise.createNoise(noiseSize, chunkX, chunkZ + 1, seed, terrainSmoothness)
			local mapNoise4 = noise.createNoise(noiseSize, chunkX + 1, chunkZ + 1, seed, terrainSmoothness)

			local mapA = {}
			local mapB = {}
			for a = 1, noiseSize do
				for b = 1, noiseSize do
					local height1 = mapNoise1[a][b]*maxHeight - 0.5*maxHeight
					local height2 = 0
					if (a < noiseSize) then
						height2 = mapNoise1[a+1][b]*maxHeight - 0.5*maxHeight
					else
						height2 = mapNoise2[1][b]*maxHeight - 0.5*maxHeight
					end
					local height3 = 0
					if (b < noiseSize) then
						height3 = mapNoise1[a][b+1]*maxHeight - 0.5*maxHeight
					else
						height3 = mapNoise3[a][1]*maxHeight - 0.5*maxHeight
					end
					local height4 = 0
					if (a == noiseSize and b == noiseSize) then
						height4 = mapNoise4[1][1]*maxHeight - 0.5*maxHeight
					elseif (a == noiseSize) then
						height4 = mapNoise2[1][b+1]*maxHeight - 0.5*maxHeight
					elseif (b == noiseSize) then
						height4 = mapNoise3[a+1][1]*maxHeight - 0.5*maxHeight
					else
						height4 = mapNoise1[a+1][b+1]*maxHeight - 0.5*maxHeight
					end

					local c1 = colors.lime
					local c2 = colors.green

					local snowHeight = relativeSnowHeight * maxHeight - 0.5*maxHeight
					local waterHeight = relativeWaterHeight * maxHeight - 0.5*maxHeight

					if (height1 >= snowHeight or height2 >= snowHeight or height3 >= snowHeight) then
						c1 = colors.white
					end
					if (height2 >= snowHeight or height3 >= snowHeight or height4 >= snowHeight) then
						c2 = colors.lightGray
					end
					if (height1 <= waterHeight or height2 <= waterHeight or height3 <= waterHeight or height4 <= waterHeight) then
						height1 = max(height1, waterHeight)
						height2 = max(height2, waterHeight)
						height3 = max(height3, waterHeight)
						height4 = max(height4, waterHeight)
						if (height1 <= waterHeight and height2 <= waterHeight and height3 <= waterHeight) then
							c1 = colors.blue
						end
						if (height2 <= waterHeight and height3 <= waterHeight and height4 <= waterHeight) then
							c2 = colors.blue
						end
					end

					local map = mapA
					if b + a > noiseSize+1 then
						map = mapB
					end

					local xOffset = 0
					local zOffset = 0
 					if map == mapA then
						xOffset = -(1/2 + 1) + -noiseSize*0.5
						zOffset = -sqrt(0.75) + -noiseSize * sqrt(0.75) / 3
					else
						xOffset = -(1/2 + 1) + -noiseSize
						zOffset = -sqrt(0.75) + -noiseSize * sqrt(0.75) * 2 / 3
					end

					map[#map+1] = {
						x1 = xOffset + b/2 + a+1, y1 = height2, z1 = zOffset + b*sqrt(0.75),
						x2 = xOffset + b/2 + a, y2 = height1, z2 = zOffset + b*sqrt(0.75),
						x3 = xOffset + b/2 + a+0.5, y3 = height3, z3 = zOffset + (b+1)*sqrt(0.75),
						c = c1,
					}

					if b + a == noiseSize+1 then
						map = mapB

						xOffset = -(1/2 + 1) + -noiseSize
						zOffset = -sqrt(0.75) + -noiseSize * sqrt(0.75) * 2 / 3
					end

					map[#map+1] = {
						x1 = xOffset + b/2 + a+0.5, y1 = height3, z1 = zOffset + (b+1)*sqrt(0.75),
						x2 = xOffset + b/2 + a+1.5, y2 = height4, z2 = zOffset + (b+1)*sqrt(0.75),
						x3 = xOffset + b/2 + a+1, y3 = height2, z3 = zOffset + b*sqrt(0.75),
						c = c2,
					}

					polyCount = polyCount + 2
				end
			end

			objects[#objects+1] = ThreeDFrame:newObject(
				mapA, -- model
				chunkX * noiseSize + chunkZ * noiseSize*0.5, -- X
				0, -- Y
				chunkZ * noiseSize * sqrt(0.75) -- Z
			)

			objects[#objects+1] = ThreeDFrame:newObject(
				mapB, -- model
				chunkX * noiseSize + chunkZ * noiseSize*0.5 + noiseSize*0.5, -- X
				0, -- Y
				chunkZ * noiseSize * sqrt(0.75) + noiseSize * sqrt(0.75)/3 -- Z
			)
		end
	end

	return objects
end

local objects = generateWorld(ThreeDFrame, genOptions)
local model = util.loadCompressedModel("/models/plane_old.cob")
local plane = ThreeDFrame:newObject(model:scale(0.33333333), camera.x + 8 * math.cos(math.rad(camera.rotY)), camera.y - 5, camera.z + 8 * math.sin(math.rad(camera.rotY)), 0, math.pi / 2 - math.rad(camera.rotY), 0)
objects[#objects+1] = plane

local function rendering()
	local frames = 0
	local lastFPSTime = 0
	while true do
		ThreeDFrame:drawObjects(objects)
		ThreeDFrame:drawBuffer()

		--[[frames = frames + 1
		if os.clock() > lastFPSTime + 1 then
			lastFPSTime = os.clock()
			term.setBackgroundColor(colors.black)
			term.setCursorPos(1, 1)
			term.clearLine()
			term.setCursorPos(1, 1)
			term.setTextColor(colors.white)
			term.write("Average FPS: " .. frames)
			frames = 0
		end]]--

		os.pullEvent("render")
	end
end

local keysDown = {}
local function keyInput()
	--[[
	while true do
		local event, key = os.pullEventRaw()

		if event == "key" then
			keysDown[key] = true
			if key == keys.g then
				highRes = not highRes
				ThreeDFrame:highResMode(highRes)
			elseif key == keys.q then
				break
			elseif key == keys.p then
				print(table.unpack(ThreeDFrame.camera))
			end
		elseif event == "key_up" then
			keysDown[key] = nil
		end
	end
	--[=[]]
	keysDown[keys.w] = true
	while camera.x < 20 and camera.z < 20 do sleep(0.05) end
	bank = 1 * math.pi / 32
	sleep(0.05)
	bank = 2 * math.pi / 32
	sleep(0.05)
	bank = 3 * math.pi / 32
	sleep(0.05)
	bank = 4 * math.pi / 32
	sleep(0.05)
	bank = 5 * math.pi / 32
	sleep(0.05)
	bank = 6 * math.pi / 32
	sleep(0.05)
	keysDown[keys.left] = true
	while camera.rotY > 10 do sleep(0.05) end
	bank = 6 * math.pi / 32
	sleep(0.05)
	bank = 5 * math.pi / 32
	sleep(0.05)
	bank = 4 * math.pi / 32
	sleep(0.05)
	bank = 3 * math.pi / 32
	sleep(0.05)
	bank = 2 * math.pi / 32
	sleep(0.05)
	bank = 1 * math.pi / 32
	sleep(0.05)
	bank = 0
	keysDown[keys.left] = false
	while camera.x < 55 do
		if os.epoch "utc" - start >= time * 1000 then break end
		sleep(0.05)
	end
	--]=]
end

local function handleCameraMovement(dt)
	local dx, dy, dz = 0, 0, 0 -- will represent the movement per second
	local render = false

	-- handle arrow keys for camera rotation
	if keysDown[keys.left] then
		camera.rotY = (camera.rotY - turnSpeed * dt) % 360
		render = true
	end
	if keysDown[keys.right] then
		camera.rotY = (camera.rotY + turnSpeed * dt) % 360
		render = true
	end
	if keysDown[keys.down] then
		camera.rotZ = math.max(-80, camera.rotZ - turnSpeed * dt)
		render = true
	end
	if keysDown[keys.up] then
		camera.rotZ = math.min(80, camera.rotZ + turnSpeed * dt)
		render = true
	end

	-- handle wasd keys for camera movement
	if keysDown[keys.w] then
		dx = speed * math.cos(math.rad(camera.rotY)) + dx
		dz = speed * math.sin(math.rad(camera.rotY)) + dz
		render = true
	end
	if keysDown[keys.s] then
		dx = -speed * math.cos(math.rad(camera.rotY)) + dx
		dz = -speed * math.sin(math.rad(camera.rotY)) + dz
		render = true
	end
	if keysDown[keys.a] then
		dx = speed * math.cos(math.rad(camera.rotY - 90)) + dx
		dz = speed * math.sin(math.rad(camera.rotY - 90)) + dz
		render = true
	end
	if keysDown[keys.d] then
		dx = speed * math.cos(math.rad(camera.rotY + 90)) + dx
		dz = speed * math.sin(math.rad(camera.rotY + 90)) + dz
		render = true
	end

	-- space and left shift key for moving the camera up and down
	if keysDown[keys.space] then
		dy = speed + dy
		render = true
	end
	if keysDown[keys.leftShift] then
		dy = -speed + dy
		render = true
	end

	-- update the camera position by adding the offset
	camera.x = camera.x + dx * dt
	camera.y = camera.y + dy * dt
	camera.z = camera.z + dz * dt

	ThreeDFrame:setCamera(camera)
	local x, y, z, w = math.cos(math.rad(camera.rotY)) * math.sin(bank/2), 0, math.sin(math.rad(camera.rotY)) * math.sin(bank/2), math.cos(bank/2)
	plane:setPos(camera.x + 8 * math.cos(math.rad(camera.rotY)), camera.y - 5, camera.z + 8 * math.sin(math.rad(camera.rotY)))
	plane:setRot(
		math.atan2(2 * (w * x + y * z), 1 - 2 * (x^2 + y^2)),
		2 * math.atan2(math.sqrt(1 + 2 * (w * y - x * z)), math.sqrt(1 - 2 * (w * y - x * z))) - math.rad(camera.rotY),
		math.atan2(2 * (w * z + x * y), 1 - 2 * (y^2 + z^2))
	)
	--plane:setRot(nil, math.pi / 2 - math.rad(camera.rotY))
	if render then os.queueEvent("render") end
end

local function gameLoop()
	local lastTime = os.clock()

	while true do
		-- compute the time passed since last step
		local currentTime = os.clock()
		local dt = currentTime - lastTime
		lastTime = currentTime

		-- run all functions that need to be run
		handleCameraMovement(dt)

		sleep(0.05)
	end
end

parallel.waitForAny(keyInput, gameLoop, rendering)
term.setBackgroundColor(colors.black)
term.setCursorPos(1, 1)
term.clear()
