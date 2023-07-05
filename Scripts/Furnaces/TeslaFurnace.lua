dofile("$CONTENT_DATA/Scripts/Furnaces/Furnace.lua")

---A TeslaFurnace sells drops depending on how much power you generate
---@class TeslaFurnace : Furnace
TeslaFurnace = class(Furnace)

--------------------
-- #region Server
--------------------

function TeslaFurnace:sv_upgrade(shape)
    local value = shape.interactable.publicData.value

    sm.effect.playEffect("PowerSocket - Activate", self.shape.worldPosition, self.shape.velocity)

    return value * math.log(g_powerManager.sv.power, 10)
end

-- #endregion
