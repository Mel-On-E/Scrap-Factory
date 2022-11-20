dofile("$CONTENT_DATA/Scripts/Drops/Drop.lua")

---@class BouncyDrop : Drop
---@field sv BouncyDrop
---@diagnostic disable-next-line: param-type-mismatch, assign-type-mismatch
BouncyDrop = class(Drop)

local velocityLimit = 1000

function BouncyDrop:server_onFixedUpdate()
    Drop.server_onFixedUpdate(self)

    if self.shape:getVelocity():length() > velocityLimit then
        self.shape:destroyShape(0)
    end
end

function BouncyDrop:server_onCollision(other, position, selfPointVelocity, otherPointVelocity, normal)
    sm.physics.applyImpulse(self.shape, normal * 10, true)

    Drop.server_onCollision(self, other, position, selfPointVelocity, otherPointVelocity, normal)
end

--Types

---@class GasDropSv : DropSv
---@field startHeight number
