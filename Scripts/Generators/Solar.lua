dofile("$CONTENT_DATA/Scripts/Generators/Generator.lua")

---A type of `Generator` that produces power only during daytime
---@class Solar : Generator
Solar = class(Generator)

--------------------
-- #region Server
--------------------

function Solar:server_onCreate()
    Generator.server_onCreate(self)
    sm.event.sendToScriptableObject(g_tutorialManager.scriptableObject, "sv_e_tryStartTutorial", "SolarTutorial")
end

function Solar:sv_getPower()
    local time = sm.game.getTimeOfDay()
    local timeMultiplier = 0

    if isDay() then
        timeMultiplier = 1
    elseif isSunrise() then
        timeMultiplier = (time - SUNRISE_START) / (SUNRISE_END - SUNRISE_START)
    elseif isSunset() then
        timeMultiplier = (SUNSET_END - time) / (SUNSET_END - SUNSET_START)
    end

    return math.floor(timeMultiplier * self.data.power)
end

--#endregion
