package.path = package.path .. ";/lib/?.lua"
local Pine3D = require "Pine3D"
local util = require "util"
local time = tonumber(...)
local start = os.epoch "utc"

---@class vector
---@field x number
---@field y number
---@field z number
---@field normalize fun(): vector
---@operator add(vector): vector
---@operator add(number): vector
---@operator sub(vector): vector
---@operator sub(number): vector
---@operator mul(number): vector
---@operator div(number): vector
---@operator unm: vector

---@type fun(x: number|nil, y: number|nil, z: number|nil): vector
local vnew = vector.new

---@class physics
---@field object PineObject
---@field position vector
---@field velocity vector
---@field acceleration vector
---@field rotation vector
---@field rotVelocity vector
---@field rotAcceleration vector
---@field mass number
local physics = {}
physics.__index = physics

---@param object PineObject
---@return physics
function physics:new(object)
    return setmetatable({
        object = object,
        position = vnew(object[1], object[2], object[3]),
        velocity = vnew(0, 0, 0),
        acceleration = vnew(0, -9.8, 0),
        rotation = vnew(0, 0, 0),
        rotVelocity = vnew(0, 0, 0),
        rotAcceleration = vnew(0, 0, 0),
        mass = 1
    }, self)
end

---@param dt number
function physics:update(dt)
    self.velocity = self.velocity + self.acceleration * dt
    self.position = self.position + self.velocity * dt
    self.rotVelocity = self.rotVelocity + self.rotAcceleration * dt
    self.rotation = self.rotation + self.rotVelocity * dt
    self.object:setPos(self.position.x, self.position.y, self.position.z)
    self.object:setRot(self.rotation.x, self.rotation.y, self.rotation.z)
end

---@param F vector
function physics:force(F)
    self.acceleration = self.acceleration + F / self.mass
end

---@param J vector
function physics:impulse(J)
    self.velocity = self.velocity + J / self.mass
end

---@param obj physics
---@param CR number|nil
function physics:elasticCollision(obj, CR)
    CR = CR or 1
    local m = self.mass + obj.mass
    local v = self.velocity
    self.velocity = (self.velocity * ((self.mass - obj.mass) / m) + obj.velocity * (obj.mass * 2 / m)) * CR
    obj.velocity = (obj.velocity * ((obj.mass - self.mass) / m) + v * (self.mass * 2 / m)) * CR
end

---@param obj physics
---@param n vector
---@param CR number|nil
function physics:inelasticCollision(obj, n, CR)
    CR = CR or 0
    n = n or vnew(0, 1, 0)
    local J = ((obj.velocity - self.velocity) * ((self.mass * obj.mass) / (self.mass + obj.mass) * (1 + CR))):dot(n)
    self:impulse(n * J)
    obj:impulse(n * J)
end

local frame = Pine3D.newFrame()
local object = frame:newObject(util.loadCompressedModel("/models/pineapple.cob"), 0, 5, -4)
local floor = frame:newObject(Pine3D.models:plane{color = colors.brown, y = 0, size = 10}, 0, 0, 0)
local physobject = physics:new(object)
physobject.velocity = vnew(0, 4, 8)
physobject.rotVelocity = vnew(0, 6 * math.pi, 0)
local physfloor = physics:new(floor)
physfloor.acceleration.y = 0
physfloor.mass = 10000000000000000000
frame:setCamera(-9, 8, 0, 0, 0, -30)
frame:setFoV(90)

frame:drawObjects({object, floor})
frame:drawBuffer()
--sleep(1)
for _ = 1, time * 20 do
    physobject:update(0.05)
    physfloor:update(0.05)
    -- Collision
    if physobject.position.y <= 1 then
        physobject.position.y = 1
        physobject:inelasticCollision(physfloor, vnew(0, 1, 0), 0.8)
        --physobject:impulse(vnew(0, (1 - physobject.position.y) / 0.05, 0))
        --print(physfloor.velocity)
        --sleep(0.5)
        --physobject.velocity = physobject.velocity - physfloor.velocity
        physfloor.velocity = vnew()
    end
    if physobject.position.z >= 4 then
        physobject.position.z = 4
        physobject:inelasticCollision(physfloor, vnew(0, 0, -1), 0.8)
        physfloor.velocity = vnew()
    end
    if physobject.position.z <= -4 then
        physobject.position.z = -4
        physobject:inelasticCollision(physfloor, vnew(0, 0, 1), 0.8)
        physfloor.velocity = vnew()
    end
    -- Ground friction
    if physobject.position.y == 1 then
        physobject:impulse(vnew(physobject.velocity.x, 0, physobject.velocity.z):normalize() * (physobject.velocity.y * -0.2))
    end
    -- Stokes' drag
    physobject:impulse(physobject.velocity * (0.5 * 0.47 * 1.164 * physobject.velocity:length() * math.pi / 40 * -0.05))
    physobject.rotAcceleration.y = math.sqrt(math.abs(physobject.rotVelocity.y)) / (physobject.rotVelocity.y < 0 and 1 or -1)
    frame:setCamera(physobject.position - vnew(3, -2, 0))
    frame:drawObjects({object, floor})
    frame:drawBuffer()
    --print(physobject.position, physobject.velocity)
    sleep(0.05)
    if (os.epoch "utc" - start) / 1000 > time then break end
end
term.setBackgroundColor(colors.black)
term.setCursorPos(1, 1)
term.clear()