dofile("$CONTENT_DATA/Scripts/util/day.lua")

---@class DayDetector : ShapeClass
---@field day boolean
---@diagnostic disable-next-line: assign-type-mismatch
DaySensor = class()
DaySensor.connectionOutput = 1
DaySensor.maxChildCount = 255
DaySensor.poseWeightCount = 1

local enabledPose = 10
local disabledPose = 0

function DaySensor:client_onCreate()
    self.day = false
end

function DaySensor:server_onFixedUpdate()
    local time = sm.game.getTimeOfDay()
    local day = not (time < SunRiseEnd or time > SunSetStart)

    if day == self.day then return end

    self.interactable:setActive(day)
    self.network:sendToClients("cl_changeModel", day)
    self.day = day
end

---@param enable boolean If true makes the model "enabled" if false "disabled"
function DaySensor:cl_changeModel(enable)
    self.interactable:setUvFrameIndex(enable and enabledPose or disabledPose)
end
