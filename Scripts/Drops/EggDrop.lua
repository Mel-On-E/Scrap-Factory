dofile("$CONTENT_DATA/Scripts/Drops/Drop.lua")

---An EggDrop
---@class EggDrop: Drop
EggDrop = class(Drop)

-- velocity threshold to destory on collisions
local velocityThreshold = 5

--------------------
-- #region Server
--------------------

function EggDrop:server_onCollision(other, position, selfVel, otherVel, normal)
    -- check if it hit something at a velocity threshold
    -- `not other` case is for when it hits the ground
    if selfVel:length() > velocityThreshold or not other then self:sv_destroy() end
    -- check if character hits at a velocity (trampeling)
    if type(other) == "Character" then
        if (normal*otherVel):length() > 2 then self:sv_destroy() end
    end
end

function EggDrop:server_onMelee(position, attacker, damage, power, direction, normal)
    self:sv_destroy()
end

function EggDrop:sv_destroy()
    self.shape:destroyShape()
    sm.effect.playEffect("Egg - Break", self.shape.worldPosition)
end

-- #endregion
