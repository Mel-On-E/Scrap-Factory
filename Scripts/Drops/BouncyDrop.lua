dofile("$CONTENT_DATA/Scripts/Drops/Drop.lua")

---@class BouncyDrop : Drop
---@field sv BouncyDrop
---@diagnostic disable-next-line: param-type-mismatch, assign-type-mismatch
BouncyDrop = class(Drop)

function BouncyDrop:server_onCollision(other, position, selfPointVelocity, otherPointVelocity, normal)
    sm.physics.applyImpulse(self.shape, normal * 10, true)

    Drop.server_onCollision(self, other, position, selfPointVelocity, otherPointVelocity, normal)
end

--Types
---@class GasDropSv : DropSv
---@field startHeight number
