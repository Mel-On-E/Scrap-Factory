---A DaySensor is a sensor that will emit a logic signal during daytime
---@class DaySensor : ShapeClass
---@diagnostic disable-next-line: assign-type-mismatch
DaySensor = class()

DaySensor.connectionOutput = sm.interactable.connectionType.logic
DaySensor.maxChildCount = 255
DaySensor.poseWeightCount = 1
DaySensor.colorNormal = sm.color.new(0x9a0d44ff)
DaySensor.colorHighlight = sm.color.new(0xc01559ff)

--------------------
-- #region Server
--------------------

function DaySensor:server_onCreate()
    self.network:sendToClients("cl_changeModel")
end

function DaySensor:server_onFixedUpdate()
    if self.interactable.active ~= isDay() then
        self.interactable:setActive(isDay())
        self.network:sendToClients("cl_changeModel")
    end
end

-- #endregion

--------------------
-- #region Client
--------------------

function DaySensor:cl_changeModel()
    self.interactable:setPoseWeight(0, self.interactable.active and 0 or 1)
end

-- #endregion
