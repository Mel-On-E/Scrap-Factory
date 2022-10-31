dofile("$CONTENT_DATA/Scripts/Furnaces/Furnace.lua")
dofile("$CONTENT_DATA/Scripts/util/day.lua")

---@class LunarFurnace : Furnace
LunarFurnace = class(Furnace)

function LunarFurnace:sv_upgrade(shape)
    local value = shape.interactable.publicData.value

    local time = sm.storage.load(STORAGE_CHANNEL_TIME).timeOfDay
    local night = time < SunRiseEnd or time > SunSetStart

    if night then
        value = value * self.data.nightMultiplier
    else
        value = value * self.data.dayMultiplier
    end

    return value
end
