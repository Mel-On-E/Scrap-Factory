dofile("$CONTENT_DATA/Scripts/util/util.lua")

---@class Dropper : ShapeClass
Dropper = class(nil)

function Dropper:server_onCreate()
    self.data = unpackNetworkData(self.data)
    self.data.drop.uuid = sm.uuid.new(self.data.drop.uuid)
    self.data.offset = sm.vec3.new(self.data.offset.x, self.data.offset.y, self.data.offset.z)

    self.sv = {}
end

function Dropper:sv_drop()
    if PowerManager.sv_changePower(-self.data.power) then
        local offset = self.shape.right * self.data.offset.x +
                       self.shape.at * self.data.offset.y +
                       self.shape.up * self.data.offset.z
                       
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