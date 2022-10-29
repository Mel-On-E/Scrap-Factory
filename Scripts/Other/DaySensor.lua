dofile("$CONTENT_DATA/Scripts/util/day.lua")

---@class DayDetector : ShapeClass
---@field day boolean
---@diagnostic disable-next-line: assign-type-mismatch
DaySensor = class()
DaySensor.connectionOutput = sm.interactable.connectionType.logic
DaySensor.maxChildCount = 255
DaySensor.poseWeightCount = 1

local enabledPose = 10

function DaySensor:client_onCreate()
    self.day = false
end

function DaySensor:server_onFixedUpdate()
    local time = sm.game.getTimeOfDay()
    local day = not (time < SunRiseEnd or time > SunSetStart)

    if day == self.day then return end

    self.interactable:setActive(day)
    self.network:sendToClients("cl_changeModel")
    self.day = day
end

function DaySensor:cl_changeModel()
    self.interactable:setUvFrameIndex(self.interactable.active and enabledPose or 0)
end
