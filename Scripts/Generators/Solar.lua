dofile("$CONTENT_DATA/Scripts/Generators/Generator.lua")
dofile("$CONTENT_DATA/Scripts/util/day.lua")


---@class Solar : Generator
Solar = class(Generator)

function Solar:server_onCreate()
    Generator.server_onCreate(self)
    sm.event.sendToScriptableObject(g_tutorialManager.scriptableObject, "sv_e_tryStartTutorial", "SolarTutorial")
end

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
