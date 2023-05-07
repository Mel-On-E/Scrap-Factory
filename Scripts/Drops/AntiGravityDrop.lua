dofile("$CONTENT_DATA/Scripts/Drops/Drop.lua")

---A AntiGravityDrop is a `Drop` that has reduced, no, or inverted gravity
---@class AntiGravityDrop : Drop
---@field data AntiGravityDropData
---@diagnostic disable-next-line: param-type-mismatch, assign-type-mismatch
AntiGravityDrop = class(Drop)

--------------------
-- #region Server
--------------------

---@type number height that is near the limit of the skybox. GasDrops will dissapear before reaching this height
local skyboxLimit = 1000

function AntiGravityDrop:server_onFixedUpdate()
    Drop.server_onFixedUpdate(self)

    local mass = self.shape:getBody().mass
    local antiGravity = (mass / 3.8186375)
    antiGravity = antiGravity * (1 - self.data.gravity)
    ---@diagnostic disable-next-line: param-type-mismatch
    sm.physics.applyImpulse(self.shape, (sm.vec3.new(0, 0, 1) * antiGravity), true)

    --destroy after travelling too far
    if self.shape.worldPosition.z > skyboxLimit then
        self.shape:destroyShape(0)
    end
end

-- #endregion

--------------------
-- #region Types
--------------------

---@class AntiGravityDropData
---@field gravity number multiplier of how much this drop is affected by gravity

-- #endregion
