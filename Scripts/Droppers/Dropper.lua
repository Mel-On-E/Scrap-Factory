dofile("$CONTENT_DATA/Scripts/util/util.lua")

---A dropper uses power to spawn shapes into the world called `Drop`.
---@class Dropper : ShapeClass
---@field sv DropperSv
---@diagnostic disable-next-line: assign-type-mismatch
Dropper = class(nil)

--------------------
-- #region Server
--------------------

function Dropper:server_onCreate()
    --tutorial event
    sm.event.sendToScriptableObject(g_tutorialManager.scriptableObject, "sv_e_questEvent", "DropperPlaced")

    self.sv = {}
    self:sv_loadDropperData()
end

---load data from the shapeset file into the data field of sv
function Dropper:sv_loadDropperData()
    self.sv.data = unpackNetworkData(self.data)
    ---@diagnostic disable-next-line: param-type-mismatch
    self.sv.data.drop.uuid = sm.uuid.new(self.sv.data.drop.uuid)
    self.sv.data.offset = sm.vec3.new(self.sv.data.offset.x, self.sv.data.offset.y, self.sv.data.offset.z)
end

---consumes power and creates a drop if power is available
function Dropper:sv_consumePowerAndDrop()
    if PowerManager.sv_changePower(-self.sv.data.power) then
        local offset = self.shape.right * self.sv.data.offset.x +
            self.shape.at * self.sv.data.offset.y +
            self.shape.up * self.sv.data.offset.z

        ---@diagnostic disable-next-line: param-type-mismatch
        local shape = sm.shape.createPart(self.sv.data.drop.uuid, self.shape:getWorldPosition() + offset,
            self.shape:getWorldRotation())

        local publicData = {
            value = self.sv.data.drop.value,
            pollution = self.sv.data.drop.pollution,
            upgrades = {}
        }
        shape.interactable:setPublicData(publicData)
    end
end

-- #endregion

--------------------
-- #region Types
--------------------

---@class DropperSv
---@field data DropperData

---@class DropperData
---@field drop DropData The data of the drop that this dropper produces
---@field offset Vec3 the offset at which a drop should be dropped
---@field power number how much power the dropper consumes

---@class DropData unpacked script data of the interactable
---@field uuid Uuid Uuid of the drop
---@field value string For how much the drop sells
---@field pollution number nil if the drop has no pollution, otherwise the pollution of the drop

-- #endregion
