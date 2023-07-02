dofile("$CONTENT_DATA/Scripts/Drops/Drop.lua")

---A CollisionExplosiveDrop is a Drop that will explode when it collides with another drop of its kind
---@class CollisionExplosiveDrop : Drop
CollisionExplosiveDrop = class(Drop)

--------------------
-- #region Server
--------------------

local destructionLevel = 5
local destructionRadius = 1
local impulseRadius = 0.01
local impulseMagnitude = 0

local triggerSize = sm.vec3.one() * 0.25

function CollisionExplosiveDrop:server_onCreate()
    Drop.server_onCreate(self)

    self.sv.trigger = sm.areaTrigger.createAttachedBox(self.interactable, triggerSize / 2, sm.vec3.zero(),
        sm.quat.identity(), sm.areaTrigger.filter.dynamicBody)
    self.sv.trigger:bindOnEnter("sv_onEnter")
end

function CollisionExplosiveDrop:sv_onEnter(_, results)
    local drops = getDrops(results)
    for _, drop in ipairs(drops) do
        if drop ~= self.shape and self.shape.uuid == drop.uuid then
            sm.physics.explode(self.shape.worldPosition, destructionLevel, destructionRadius, impulseRadius,
                impulseMagnitude, "PropaneTank - ExplosionSmall")
            sm.shape.destroyShape(self.shape, 0)
            return
        end
    end
end

-- #endregion
