dofile("$CONTENT_DATA/Scripts/Furnaces/Furnace.lua")

---The LunarFurnace sells drops for less during day, but for more during night.
---@class LunarFurnace : Furnace
LunarFurnace = class(Furnace)

--------------------
-- #region Server
--------------------

function LunarFurnace:sv_upgrade(shape)
    local value = shape.interactable.publicData.value

    if isDay() then
        value = value * self.data.dayMultiplier
    else
        value = value * self.data.nightMultiplier
    end

    return value
end

-- #endregion
