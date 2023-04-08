dofile("$CONTENT_DATA/Scripts/Drops/Drop.lua")

---A MagneticDrop is a `Drop` that is attracted to drops of opposite magnetic polarisation and attracted to drops of opposite.
---@class MagneticDrop : Drop
---@field data MagneticDropData
---@diagnostic disable-next-line: param-type-mismatch, assign-type-mismatch
MagneticDrop = class(Drop)

--------------------
-- #region Server
--------------------

local magneticDrops = {
    tick = sm.game.getCurrentTick(),
    drops = {}
}

function MagneticDrop:server_onCreate()
    Drop.server_onCreate(self)

    magneticDrops.drops[#magneticDrops.drops + 1] = {
        south = self.data.south,
        shape = self.shape
    }
end

function MagneticDrop:server_onFixedUpdate()
    Drop.server_onFixedUpdate(self)

    --update magnetic drops
    if magneticDrops.tick < sm.game.getCurrentTick() then
        magneticDrops.tick = sm.game.getCurrentTick()

        --clear old drops
        for k, v in pairs(magneticDrops.drops) do
            if not v.shape or not sm.exists(v.shape) then
                magneticDrops.drops[k] = nil
            end
        end

        --apply magnetic force to each drop
        for k1, v1 in pairs(magneticDrops.drops) do
            local force = sm.vec3.zero()
            for k2, v2 in pairs(magneticDrops.drops) do
                if v1 ~= v2 then
                    local direction = (v1.south == v2.south and -1) or 1

                    local distance = v2.shape.worldPosition - v1.shape.worldPosition
                    local factor = 1 / distance:length()
                    force = force + distance:normalize() * direction * factor
                end
            end
            sm.physics.applyImpulse(v1.shape:getBody(), force, true)
        end
    end
end

-- #endregion

--------------------
-- #region Types
--------------------

---@class MagneticDropData
---@field north boolean whether this drop is a north pole
---@field south boolean whether this drop is a south pole

-- #endregion
