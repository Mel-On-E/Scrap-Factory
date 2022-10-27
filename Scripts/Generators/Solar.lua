dofile("$CONTENT_DATA/Scripts/Generators/Generator.lua")
dofile("$CONTENT_DATA/Scripts/util/day.lua")


---@class Solar : Generator
Solar = class(Generator)

function Solar:getPower()
    local time = sm.storage.load(STORAGE_CHANNEL_TIME).timeOfDay
    local timeMultiplier = 0

    if time > SunRiseStart and time < SunRiseEnd then
        timeMultiplier = (time - SunRiseStart) / (SunRiseEnd - SunRiseStart)
    elseif time > SunRiseEnd and time < SunSetStart then
        timeMultiplier = 1
    elseif time > SunSetStart and time < SunSetEnd then
        timeMultiplier = (time - SunSetStart) / (SunSetEnd - SunSetStart)
    end

    return math.floor(timeMultiplier * self.data.power)
end
