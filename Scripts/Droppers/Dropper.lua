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

    if self.sv.data.drop then
        ---@diagnostic disable-next-line: param-type-mismatch
        self.sv.data.drop.uuid = sm.uuid.new(self.sv.data.drop.uuid)
    elseif self.sv.data.drops then
        local sum = 0
        for k, v in ipairs(self.sv.data.drops) do
            ---@diagnostic disable-next-line: param-type-mismatch
            self.sv.data.drops[k].uuid = sm.uuid.new(v.uuid)
            sum = sum + v.chance
        end
        self.sv.data.chanceSum = sum
    end

    self.sv.data.offset = sm.vec3.new(self.sv.data.offset.x, self.sv.data.offset.y, self.sv.data.offset.z)
end

---consumes power and creates a drop if power is available
function Dropper:sv_consumePowerAndDrop()
    if PowerManager.sv_changePower(-self.sv.data.power) then
        local offset = self.shape.right * self.sv.data.offset.x +
            self.shape.at * self.sv.data.offset.y +
            self.shape.up * self.sv.data.offset.z

        --get drop data
        local drop, value, pollution
        if self.sv.data.drop then
            drop = self.sv.data.drop.uuid
            value = self.sv.data.drop.value
            pollution = self.sv.data.drop.pollution
        elseif self.sv.data.drops then
            local chance = math.random() * self.sv.data.chanceSum
            for _, droop in ipairs(self.sv.data.drops) do
                chance = chance - droop.chance
                if chance <= 0 then
                    drop = droop.uuid
                    value = droop.value
                    pollution = droop.pollution
                    goto dropFound
                end
            end
            ::dropFound::
        end

        --spawn drop
        ---@diagnostic disable-next-line: param-type-mismatch
        local shape = sm.shape.createPart(drop, self.shape.worldPosition + offset,
            self.shape:getWorldRotation())
        if self.sv.data.dropEffect then
            sm.effect.playEffect(self.sv.data.dropEffect, self.shape.worldPosition + offset)
        end

        local publicData = {
            value = value,
            pollution = pollution,
            upgrades = {},
            impostor = false,
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
---@field drop DropData|nil The data of the drop that this dropper produces
---@field offset Vec3 the offset at which a drop should be dropped
---@field power number how much power the dropper consumes
---@field drops table<integer, DropsData>|nil
---@field chanceSum integer|nil the chance of all drops combined
---@field dropEffect string|nil name of an effect to be played when a drop spawns

---@class DropData unpacked script data of the interactable
---@field uuid Uuid Uuid of the drop
---@field value string For how much the drop sells
---@field pollution number|nil nil if the drop has no pollution, otherwise the pollution of the drop

---@class DropsData : DropData
---@field chance number how likely this drop is to drop

-- #endregion
