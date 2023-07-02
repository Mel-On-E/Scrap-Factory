dofile("$CONTENT_DATA/Scripts/Drops/Drop.lua")

---A BouncyDrop is a Drop that will bounce whenever it collides with something
---@class BouncyDrop : Drop
BouncyDrop = class(Drop)

--------------------
-- #region Server
--------------------

function BouncyDrop:server_onCollision(other, _, _, _, normal)
    sm.physics.applyImpulse(self.shape, normal * 10, true)

    Drop.server_onCollision(self, other)
end

-- #endregion
