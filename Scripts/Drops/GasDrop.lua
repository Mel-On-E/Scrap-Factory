dofile("$CONTENT_DATA/Scripts/Drops/Drop.lua")

---A GasDrop is a Drop that floats towards the sky and eventually dissapears after reaching a certain height
---@class GasDrop : Drop
---@field sv GasDropSv
GasDrop = class(Drop)

--------------------
-- #region Server
--------------------

---@type number height travelled after which the drop depsawns
local despawnHeight = 69
---@type number height that is near the limit of the skybox. GasDrops will dissapear before reaching this height
local skyboxLimit = 1000

function GasDrop:server_onCreate()
    Drop.server_onCreate(self)
    self.sv.startHeight = self.shape.worldPosition.z
end

function GasDrop:server_onFixedUpdate()
    Drop.server_onFixedUpdate(self)

    self:sv_applyImpulse()
    self:sv_destroyFarTravelledDrops()
end

---apply upwards impulse and a bit of random jitter
---@param self Drop|GasDrop
function GasDrop:sv_applyImpulse()
    local mass = self.shape:getBody().mass
    local jitter = sm.vec3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5)
    ---@diagnostic disable-next-line: param-type-mismatch
    sm.physics.applyImpulse(self.shape, (sm.vec3.new(0, 0, 1) * (mass / 3.4)) + jitter, true)
end

---destroy after travelling too far
---@param self Drop|GasDrop
function GasDrop:sv_destroyFarTravelledDrops()
    local height = self.shape.worldPosition.z
    if (height > skyboxLimit) or ((height - self.sv.startHeight) > despawnHeight) then
        self.shape:destroyShape(0)
    end
end

-- #endregion

--------------------
-- #region Types
--------------------

---@class GasDropSv : DropSv
---@field startHeight number height at which the drop was spawned.

-- #endregion
