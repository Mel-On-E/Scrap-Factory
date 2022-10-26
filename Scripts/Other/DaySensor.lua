dofile("$CONTENT_DATA/Scripts/util/day.lua")

---@class DayDetector : ShapeClass
---@field night boolean
---@diagnostic disable-next-line: assign-type-mismatch
DaySensor = class()
DaySensor.connectionOutput = 1
DaySensor.maxChildCount = 10
DaySensor.poseWeightCount = 1



function DaySensor:client_onCreate()
    self.night = false
end

function DaySensor:server_onFixedUpdate()
    local time = sm.game.getTimeOfDay()
    local night = time < SunRiseEnd or time > SunSetStart

    if night == self.night then return end

    self.interactable:setActive(night)
    self.network:sendToClients("cl_changeModel", night)
    self.night = night
end

---@param enable boolean If true makes the model "enabled" if false "disabled"
function DaySensor:cl_changeModel(enable)
    self.interactable:setUvFrameIndex(enable and 10 or 0)
end
