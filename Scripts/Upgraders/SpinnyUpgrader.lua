dofile("$CONTENT_DATA/Scripts/Upgraders/Upgrader.lua")

---@class RandomUpgrader : Upgrader
SpinnyUpgrader = class(Upgrader)

function SpinnyUpgrader:sv_onUpgrade(shape)
    local publicData = shape.interactable:getPublicData()
    local upgrade = self.data.upgrade
    if upgrade.multiplier then
        local angular = math.min(self.shape.body.angularVelocity:length(), upgrade.maxSpin)
        local upgradeFraction = angular / upgrade.maxSpin
        publicData.value = publicData.value + (publicData.value * (upgrade.multiplier * upgradeFraction))
    end
    sm.event.sendToInteractable(shape.interactable, "sv_e_createEffect",
        { effect = "ShapeRenderable", key = tostring(self.shape.uuid),
            uuid = sm.uuid.new("bbc5cc77-443d-4aa7-a175-ebdeb09c2df3"),
            color = sm.color.new(1, 0.753, 0.796), scale = sm.vec3.one() / 4 })
    return publicData
end

function SpinnyUpgrader:server_onCreate()
    local size, offset = self:get_size_and_offset()

    self.upgradeTrigger = sm.areaTrigger.createAttachedBox(self.interactable, size / 2, offset, sm.quat.identity(),
        sm.areaTrigger.filter.dynamicBody)
    self.upgradeTrigger:bindOnEnter("sv_onEnter")
    Power.server_onCreate(self)
end

function SpinnyUpgrader:server_onFixedUpdate()
    Belt.server_onFixedUpdate(self)

    local size, offset = self:get_size_and_offset()
    self.upgradeTrigger:setSize(size / 2)
end

function SpinnyUpgrader:client_onCreate()
    Belt.client_onCreate(self)

    local size, offset = self:get_size_and_offset()

    self.cl.effect = sm.effect.createEffect("ShapeRenderable", self.interactable)
    self.cl.effect:setParameter("uuid", sm.uuid.new("bbc5cc77-443d-4aa7-a175-ebdeb09c2df3"))
    self.cl.effect:setParameter("color", sm.color.new(1, 0.753, 0.796))
    self.cl.effect:setScale(size)
    self.cl.effect:setOffsetPosition(offset)
    self.cl.effect:start()
end

function SpinnyUpgrader:client_onFixedUpdate()
    local size, offset = self:get_size_and_offset()

    self.cl.effect:setScale(size)
    self.cl.effect:setOffsetPosition(offset)
end

function SpinnyUpgrader:get_size_and_offset()
    local offset = sm.vec3.new(self.data.upgrade.offset.x, self.data.upgrade.offset.y, self.data.upgrade.offset.z)

    local size = sm.vec3.new(self.data.upgrade.sphere.x, self.data.upgrade.sphere.y, self.data.upgrade.sphere.z)
    local height = sm.vec3.one() - size
    local speed = math.min(self.shape.body.angularVelocity:length() ^ 0.333, self.data.upgrade.maxSpin)
    size = size * speed
    size = size + self.shape:getBoundingBox()


    return size, offset
end
