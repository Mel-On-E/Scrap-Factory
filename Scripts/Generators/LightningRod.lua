dofile("$CONTENT_DATA/Scripts/Generators/Generator.lua")

---A type of `Generator` that produces power when hit by lightning
---@class LightningRod : Generator
LightningRod = class(Generator)

--------------------
-- #region Server
--------------------

function LightningRod:server_onCreate()
    Generator.server_onCreate(self)
    self.sv.powerGenerated = 0
end

function LightningRod:server_onFixedUpdate()
    if math.random() * 300 < self:get_height_multiplier() then
        local offset = sm.vec3.new(0, 0, self.shape:getBoundingBox().z)
        sm.effect.playEffect("PowerSocket - Activate", self.shape.worldPosition + offset)
        self.sv.powerGenerated = self.sv.powerGenerated + self.data.power
        PowerManager.sv_changePower(self.data.power)
        self.network:setClientData({ power = tostring(self.sv.powerGenerated) })
    end

    if sm.game.getCurrentTick() % 40 == 0 then
        self.network:setClientData({ power = tostring(self.sv.powerGenerated) })
        self.sv.powerGenerated = 0
    end
end

-- #endregion

function LightningRod:get_height_multiplier()
    return sm.util.clamp(self.shape.worldPosition.z / 100 + 1, 0.1, 3)
end
