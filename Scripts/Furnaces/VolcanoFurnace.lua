dofile("$CONTENT_DATA/Scripts/Furnaces/Furnace.lua")

---A VolcanoFurnace erupts randomly. Drops are sold for more during an eruption.
---@class VolcanoFurnace : Furnace
---@field sv VolcanoFurnaceSv
VolcanoFurnace = class(Furnace)

--------------------
-- #region Server
--------------------

local minEruptionWait = 40 * 10
local maxEruptionWait = 40 * 60
local minEruptionDuration = 40 * 5
local maxEruptionDuration = 40 * 15
local explosionChance = 0.025

function VolcanoFurnace:server_onCreate()
    Furnace.server_onCreate(self)

    self.sv.nextEruption = math.random(minEruptionWait, maxEruptionWait)
    self.sv.eruptionDuration = 0
end

function VolcanoFurnace:server_onFixedUpdate()
    Furnace.server_onFixedUpdate(self)

    if self.sv.eruptionDuration > 0 then
        self.sv.eruptionDuration = self.sv.eruptionDuration - 1

        if math.random() <= explosionChance then
            local pos = self.shape.worldPosition
            local size = self.shape:getBoundingBox()
            pos.x = pos.x + (math.random() - 0.5) * size.x / 2
            pos.y = pos.y + (math.random() - 0.5) * size.y / 2
            sm.physics.explode(pos, 1, 0, 2, 1, "PropaneTank - ExplosionSmall")
        end
    else
        self.sv.nextEruption = self.sv.nextEruption - 1

        if self.sv.nextEruption == 0 then
            self.sv.eruptionDuration = math.random(minEruptionDuration, maxEruptionDuration)
            self.sv.nextEruption = math.random(minEruptionWait, maxEruptionWait)
        end
    end
end

function VolcanoFurnace:sv_upgrade(shape)
    local value = shape.interactable.publicData.value

    if self.sv.eruptionDuration > 0 then
        value = value * self.data.erruptionMultiplier
    else
        value = value * self.data.multiplier
    end

    return value
end

-- #endregion

--------------------
-- #region Types
--------------------

---@class VolcanoFurnaceSv : FurnaceSv
---@field nextEruption integer in how many ticks the next eruption occurs
---@field eruptionDuration integer how many ticks the current eruption has left

-- #endregion
