dofile("$CONTENT_DATA/Scripts/util/day.lua")

---@class DayDetector : ShapeClass
---@field day boolean
---@diagnostic disable-next-line: assign-type-mismatch
DaySensor = class()
DaySensor.connectionOutput = sm.interactable.connectionType.logic
DaySensor.maxChildCount = 255
DaySensor.poseWeightCount = 1
DaySensor.colorNormal = sm.color.new(0x9a0d44ff)
DaySensor.colorHighlight = sm.color.new(0xc01559ff)

local enabledPose = 10

function DaySensor:server_onCreate()
    self.sv = {}
    self.sv.day = false

    self.network:sendToClients("cl_changeModel")
end

function DaySensor:server_onFixedUpdate()
    local day = isDay()

    if day == self.sv.day then return end

    self.interactable:setActive(day)
    self.network:sendToClients("cl_changeModel")
    self.sv.day = day
end

function DaySensor:cl_changeModel()
    self.interactable:setPoseWeight(0, self.interactable.active and 0 or 1)
end
