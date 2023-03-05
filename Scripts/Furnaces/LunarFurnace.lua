dofile("$CONTENT_DATA/Scripts/Furnaces/Furnace.lua")
dofile("$CONTENT_DATA/Scripts/util/day.lua")

---The LunarFurnace sells drops for less during day, but for more during night.
---@class LunarFurnace : Furnace
LunarFurnace = class(Furnace)

function LunarFurnace:sv_upgrade(shape)
    local value = shape.interactable.publicData.value

    if isDay() then
        value = value * self.data.dayMultiplier
    else
        value = value * self.data.nightMultiplier
    end

    return value
end
