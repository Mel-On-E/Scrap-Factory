dofile("$CONTENT_DATA/Scripts/util/util.lua")

Dropper = class( nil )

function Dropper:server_onCreate()
    self.data.power = tonumber(self.data.power)

    self.drop = sm.uuid.new(self.data.drop.uuid)
    self.offset = sm.vec3.new(self.data.offset.x, self.data.offset.y, self.data.offset.z)
end

function Dropper:sv_drop()
    if PowerManager.sv_changePower(-self.data.power) then
        local offset = self.shape.right * self.offset.x + self.shape.at * self.offset.y + self.shape.up * self.offset.z
        local shape = sm.shape.createPart(self.drop, self.shape:getWorldPosition() + offset, self.shape:getWorldRotation())

        local publicData = {}
        publicData.value = tonumber(self.data.drop.value)
        publicData.pollution = (self.data.drop.pollution and tonumber(self.data.drop.pollution)) or nil
        publicData.upgrades = {}

        shape.interactable:setPublicData(publicData)
    end
end