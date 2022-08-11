dofile("$CONTENT_DATA/Scripts/Belt.lua")
dofile("$CONTENT_DATA/Scripts/util/power.lua")

Upgrader = class(nil)
Upgrader.maxParentCount = 1
Upgrader.maxChildCount = 0
Upgrader.connectionInput = sm.interactable.connectionType.logic
Upgrader.connectionOutput = sm.interactable.connectionType.none
Upgrader.colorNormal = sm.color.new( 0x00dd00ff )
Upgrader.colorHighlight = sm.color.new( 0x00ff00ff )

function get_size_and_offset(self)
    local size = sm.vec3.new(self.data.upgrade.box.x, self.data.upgrade.box.y, self.data.upgrade.box.z)
    local offset = sm.vec3.new(self.data.upgrade.offset.x, self.data.upgrade.offset.y, self.data.upgrade.offset.z)
    return size, offset
end

function Upgrader:server_onCreate()
    self.data.upgrade.add = tonumber(self.data.upgrade.add)

    local size, offset = get_size_and_offset(self)

    self.upgradeTrigger = sm.areaTrigger.createAttachedBox(self.interactable, size / 2, offset, sm.quat.identity(),
        sm.areaTrigger.filter.dynamicBody)
    self.upgradeTrigger:bindOnEnter("sv_onEnter")
    Power.server_onCreate(self)
end

function Upgrader:server_onFixedUpdate()
    Power.server_onFixedUpdate(self, "cl_toggleEffect")
end

function Upgrader:client_onCreate()
    local size, offset = get_size_and_offset(self)

    self.effect = sm.effect.createEffect("ShapeRenderable", self.interactable)
    self.effect:setParameter("uuid", sm.uuid.new("5f41af56-df4c-4837-9b3c-10781335757f"))
    self.effect:setParameter("color", sm.color.new(1, 1, 1))
    self.effect:setScale(size)
    self.effect:setOffsetPosition(offset)
    self.effect:start()
end

function Upgrader:sv_onEnter(trigger, results)
    if not self.active then return end
    for _, result in ipairs(results) do
        if not sm.exists(result) then return end
        for k, shape in ipairs(result:getShapes()) do
            local interactable = shape:getInteractable()
            if not interactable then return end
            local data = interactable:getPublicData()
            if not data or not data.value then return end
            local uuid = tostring(self.shape.uuid)
            if data.value > self.data.upgrade.cap then goto continue end
            if data.upgrades[uuid] and data.upgrades[uuid] >= self.data.upgrade.limit then goto continue end

            data.value = data.value * self.data.upgrade.multiplier + self.data.upgrade.add
            data.upgrades[uuid] = data.upgrades[uuid] and data.upgrades[uuid] + 1 or 1
            interactable:setPublicData(data)
        end
        ::continue::
    end
end

function Upgrader:cl_toggleEffect(active)
    if active and not self.effect:isPlaying() then
        self.effect:start()
    else
        self.effect:stop()
    end
end


BeltUpgrader = class(Upgrader)

function BeltUpgrader:server_onCreate()
    Belt.server_onCreate(self)
    Upgrader.server_onCreate(self)
end

function BeltUpgrader:sv_onStay(trigger, results)
    Belt.sv_onStay(self, trigger, results)
end
