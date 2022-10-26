dofile("$CONTENT_DATA/Scripts/Generators/Generator.lua")


---@class Solar : Generator
Solar = class(Generator)

local sunRiseStart = 0.16
local sunRiseEnd = 0.24
local sunSetStart = 0.76
local sunSetEnd = 0.84

function Solar:getPower()
    local time = sm.storage.load(STORAGE_CHANNEL_TIME).timeOfDay
    local timeMultiplier = 0

    if time > sunRiseStart and time < sunRiseEnd then
        timeMultiplier = (time - sunRiseStart) / (sunRiseEnd - sunRiseStart)
    elseif time > sunRiseEnd and time < sunSetStart then
        timeMultiplier = 1
    elseif time > sunSetStart and time < sunSetEnd then
        timeMultiplier = (time - sunSetStart) / (sunSetEnd - sunSetStart)
    end

    return math.floor(timeMultiplier * self.data.power)
end
