dofile("$CONTENT_DATA/Scripts/Drops/Drop.lua")

---An AntiMatterDrop is made out of anti matter and will explode once it touches ANYTHING!
---@class AntiMatterDrop : Drop
---@diagnostic disable-next-line: param-type-mismatch, assign-type-mismatch
AntiMatterDrop = class(Drop)

--------------------
-- #region Server
--------------------

function AntiMatterDrop:server_onCollision(other, position, selfPointVelocity, otherPointVelocity, normal)
    sm.physics.explode(self.shape.worldPosition, 5, 10, 20, 20, "PropaneTank - ExplosionBig")
    self.shape:destroyPart(0)
end

-- #endregion
