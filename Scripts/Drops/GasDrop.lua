dofile("$CONTENT_DATA/Scripts/Drops/Drop.lua")

---@class GasDrop : Drop
---@field sv GasDropSv
---@diagnostic disable-next-line: param-type-mismatch, assign-type-mismatch
GasDrop = class(Drop)

local despawnHeight = 69
local skyboxLimit = 1000

function GasDrop:server_onCreate()
    Drop.server_onCreate(self)
    self.sv.startHeight = self.shape.worldPosition.z
end

function GasDrop:server_onFixedUpdate()
    Drop.server_onFixedUpdate(self)

    local mass = self.shape:getBody().mass
    local jitter = sm.vec3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5)
    ---@diagnostic disable-next-line: param-type-mismatch
    sm.physics.applyImpulse(self.shape, (sm.vec3.new(0, 0, 1) * (mass / 3.4)) + jitter, true)

    local height = self.shape.worldPosition.z
    if (height > skyboxLimit) or ((height - self.sv.startHeight) > despawnHeight) then
        self.shape:destroyShape(0)
    end
end

--Types

---@class GasDropSv : DropSv
---@field startHeight number
