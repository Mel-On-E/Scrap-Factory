SunRiseStart = 0.16
SunRiseEnd = 0.24
SunSetStart = 0.76
SunSetEnd = 0.84

function isDay()
    local time = sm.game.getTimeOfDay()
    return time > SunRiseEnd and time < SunSetStart
end

function isSunrise()
    local time = sm.game.getTimeOfDay()
    return time > SunRiseStart and time < SunRiseEnd
end

function isSunset()
    local time = sm.game.getTimeOfDay()
    return time > SunSetStart and time < SunSetEnd
end