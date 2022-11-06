dofile("$CONTENT_DATA/Scripts/util/util.lua")

---@class Dropper : ShapeClass
---@field cl DropperCl
---@field sv DropperSv
---@field data DropperData
---@diagnostic disable-next-line: assign-type-mismatch
Dropper = class(nil)

function Dropper:server_onCreate()
    sm.event.sendToScriptableObject(g_tutorialManager.scriptableObject, "sv_e_questEvent", "DropperPlaced")

    self.data = unpackNetworkData(self.data)
    ---@diagnostic disable-next-line: param-type-mismatch
    self.data.drop.uuid = sm.uuid.new(self.data.drop.uuid)
    self.data.offset = sm.vec3.new(self.data.offset.x, self.data.offset.y, self.data.offset.z)

    self.sv = {}
end

function Dropper:sv_drop()
    if PowerManager.sv_changePower(-self.data.power) then
        local offset = self.shape.right * self.data.offset.x +
            self.shape.at * self.data.offset.y +
            self.shape.up * self.data.offset.z

        ---@diagnostic disable-next-line: param-type-mismatch
        local shape = sm.shape.createPart(self.data.drop.uuid, self.shape:getWorldPosition() + offset,
            self.shape:getWorldRotation())

        local publicData = {}
        publicData.value = self.data.drop.value
        publicData.pollution = self.data.drop.pollution
        publicData.upgrades = {}

        shape.interactable:setPublicData(publicData)
    end
end

function Dropper:client_onCreate()
    self.cl = {}
end

--Types


---@class DropperCl


---@class DropperSv

---@class DropperData
---@field drop Drop The data of the drop that this dropper produces
---@field offset Vec3
---@field power number

---@class Drop
---@field uuid Uuid Uuid of the drop
---@field value string For how much the drop sells
---@field pollution number
