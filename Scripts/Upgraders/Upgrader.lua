dofile("$CONTENT_DATA/Scripts/Other/Belt.lua")
dofile("$CONTENT_DATA/Scripts/util/power.lua")

---@class Upgrader : ShapeClass
Upgrader = class()
Upgrader.maxParentCount = 1
Upgrader.maxChildCount = 0
Upgrader.connectionInput = sm.interactable.connectionType.logic
Upgrader.connectionOutput = sm.interactable.connectionType.none
Upgrader.colorNormal = sm.color.new(0x00dd00ff)
Upgrader.colorHighlight = sm.color.new(0x00ff00ff)

function get_size_and_offset(self)
    local size = sm.vec3.new(self.data.upgrade.box.x, self.data.upgrade.box.y, self.data.upgrade.box.z)
    local offset = sm.vec3.new(self.data.upgrade.offset.x, self.data.upgrade.offset.y, self.data.upgrade.offset.z)
    return size, offset
end

function Upgrader:server_onCreate()
    self.data.upgrade.add = tonumber(self.data.upgrade.add)

    if self.data.belt then
        Belt.server_onCreate(self)
        self.sv_onStay = Belt.sv_onStay
    end

    local size, offset = get_size_and_offset(self)

    self.upgradeTrigger = sm.areaTrigger.createAttachedBox(self.interactable, size / 2, offset, sm.quat.identity(),
        sm.areaTrigger.filter.dynamicBody)
    self.upgradeTrigger:bindOnEnter("sv_onEnter")
    Power.server_onCreate(self)
end

function Upgrader:server_onFixedUpdate()
    Belt.server_onFixedUpdate(self)
end

function Upgrader:sv_onEnter(trigger, results)
    if not self.powerUtil.active then return end
    for _, result in ipairs(results) do
        if not sm.exists(result) then return end
        for k, shape in ipairs(result:getShapes()) do
            local interactable = shape:getInteractable()
            if not interactable then return end
            local data = interactable:getPublicData()
            if not data or not data.value then return end
            local uuid = tostring(self.shape.uuid)
            if self.data.upgrade.cap and data.value > self.data.upgrade.cap then goto continue end
            if self.data.upgrade.limit and data.upgrades[uuid] and data.upgrades[uuid] >= self.data.upgrade.limit then goto continue end

            data = self:sv_onUpgrade(shape)
            data.upgrades[uuid] = data.upgrades[uuid] and data.upgrades[uuid] + 1 or 1
            interactable:setPublicData(data)
        end
        ::continue::
    end
end

function Upgrader:sv_onUpgrade(shape)
    local data = shape.interactable:getPublicData()
    local upgrade = self.data.upgrade
    if upgrade.multiplier then
        data.value = data.value * upgrade.multiplier
    end
    if upgrade.add then
        data.value = data.value + upgrade.add
    end
    return data
end

function Upgrader:client_onCreate()
    Belt.client_onCreate(self)

    local size, offset = get_size_and_offset(self)

    self.cl.effect = sm.effect.createEffect("ShapeRenderable", self.interactable)
    self.cl.effect:setParameter("uuid", sm.uuid.new("5f41af56-df4c-4837-9b3c-10781335757f"))
    self.cl.effect:setParameter("color", sm.color.new(1, 1, 1))
    self.cl.effect:setScale(size)
    self.cl.effect:setOffsetPosition(offset)
    self.cl.effect:start()
end

function Upgrader:client_onUpdate(dt)
    Belt.client_onUpdate(self, dt)
end

function Upgrader:cl_toggleEffects(active)
    Belt.cl_toggleEffects(self, active)
    if active and not self.cl.effect:isPlaying() then
        self.cl.effect:start()
    else
        self.cl.effect:stop()
    end
end
