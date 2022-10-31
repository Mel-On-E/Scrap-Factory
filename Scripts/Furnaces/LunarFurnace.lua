dofile("$CONTENT_DATA/Scripts/Furnaces/Furnace.lua")
dofile("$CONTENT_DATA/Scripts/util/day.lua")

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
