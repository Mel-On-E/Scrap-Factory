---@class DayDetector : ShapeClass
---@field night boolean
---@diagnostic disable-next-line: assign-type-mismatch
DaySensor = class()
DaySensor.connectionOutput = 1
DaySensor.maxChildCount = 10
DaySensor.poseWeightCount = 1

local sunRiseEnd = 0.24
local sunSetStart = 0.76

function DaySensor:client_onCreate()
    self.night = false
end

function DaySensor:server_onFixedUpdate()
    local time = sm.game.getTimeOfDay()
    local night = time < sunRiseEnd or time > sunSetStart

    if night == self.night then return end

    self.interactable:setActive(night)
    self.network:sendToClients("cl_changePose", { index = 0, pose = night and 1 or 0 })
    self.night = night
end

---Set the pose weight of the pose in the given index.
---@param args table
function DaySensor:cl_changePose(args)
    self.interactable:setPoseWeight(args.index, args.pose)
end
