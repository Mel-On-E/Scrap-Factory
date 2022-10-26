dofile("$CONTENT_DATA/Scripts/Furnaces/Furnace.lua")

local sunRiseEnd = 0.24
local sunSetStart = 0.76

---@class LunarFurnace : Furnace
LunarFurnace = class(Furnace)

function LunarFurnace:sv_upgrade(shape)
    local value = shape.interactable.publicData.value

    local time = sm.storage.load(STORAGE_CHANNEL_TIME).timeOfDay
    local night = time < sunRiseEnd or time > sunSetStart

    if night then
        if self.data.nightMultiplier then
            value = value * self.data.nightMultiplier
        end
    else
        if self.data.dayMultiplier then
            value = value * self.data.dayMultiplier
        end
    end

    return value
end
