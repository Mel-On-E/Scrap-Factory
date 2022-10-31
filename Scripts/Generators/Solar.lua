dofile("$CONTENT_DATA/Scripts/Generators/Generator.lua")
dofile("$CONTENT_DATA/Scripts/util/day.lua")


---@class Solar : Generator
Solar = class(Generator)

function Solar:getPower()
    local time = sm.game.getTimeOfDay()
    local timeMultiplier = 0

    if isDay() then
        timeMultiplier = 1
    elseif isSunrise() then
        timeMultiplier = (time - SunRiseStart) / (SunRiseEnd - SunRiseStart)
    elseif isSunset() then
        timeMultiplier = (SunSetEnd - time) / (SunSetEnd - SunSetStart)
    end

    return math.floor(timeMultiplier * self.data.power)
end
