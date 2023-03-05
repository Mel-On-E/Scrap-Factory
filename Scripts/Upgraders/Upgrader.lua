dofile("$CONTENT_DATA/Scripts/Other/Belt.lua")

---@class Upgrader : ShapeClass
---@field powerUtil PowerUtility
Upgrader = class()
Upgrader.maxParentCount = 1
Upgrader.maxChildCount = 0
Upgrader.connectionInput = sm.interactable.connectionType.logic
Upgrader.connectionOutput = sm.interactable.connectionType.none
Upgrader.colorNormal = sm.color.new(0x00dd00ff)
Upgrader.colorHighlight = sm.color.new(0x00ff00ff)

function Upgrader:get_size_and_offset()
    local size = sm.vec3.new(self.data.upgrade.box.x, self.data.upgrade.box.y, self.data.upgrade.box.z)
    local offset = sm.vec3.new(self.data.upgrade.offset.x, self.data.upgrade.offset.y, self.data.upgrade.offset.z)
    return size, offset
end

---@class Params
---@field filters number filters of the areaTrigger
---@param params Params
function Upgrader:server_onCreate(params)
    params = params or {}

    if self.data.belt then
        Belt.server_onCreate(self)
        self.sv_onStay = Belt.sv_onStay
    else
        PowerUtility.sv_init(self)
    end

    local size, offset = self:get_size_and_offset()

    self.upgradeTrigger = sm.areaTrigger.createAttachedBox(self.interactable, size / 2, offset, sm.quat.identity(),
        params.filters or sm.areaTrigger.filter.dynamicBody)
    self.upgradeTrigger:bindOnEnter("sv_onEnter")
end

function Upgrader:server_onFixedUpdate()
    if self.data.belt then
        Belt.server_onFixedUpdate(self)
    else
        PowerUtility.sv_fixedUpdate(self, nil)
    end
end

function Upgrader:sv_onEnter(trigger, results)
    if not self.powerUtil.active then return end
    for _, result in ipairs(results) do
        if not sm.exists(result) then goto continue end
        if type(result) ~= "Body" then goto continue end

        for k, shape in ipairs(result:getShapes()) do
            local interactable = shape:getInteractable()
            if not interactable then return end
            local data = interactable:getPublicData()
            if not data or not data.value then return end
            local uuid = tostring(self.shape.uuid)
            if self.data.upgrade.cap and data.value > self.data.upgrade.cap then goto continue end
            if self.data.upgrade.limit and data.upgrades[uuid] and data.upgrades[uuid] >= self.data.upgrade.limit then goto continue end

            self:sv_onUpgrade(shape, data)
        end
        ::continue::
    end
end

function Upgrader:sv_onUpgrade(shape, data)
    local uuid = tostring(self.shape.uuid)

    data.upgrades[uuid] = data.upgrades[uuid] and data.upgrades[uuid] + 1 or 1
    shape.interactable:setPublicData(data)
end

function Upgrader:client_onCreate()
    if self.data.belt then
        Belt.client_onCreate(self)
    else
        self.cl = {}
    end

    self:cl_createUpgradeEffect()
end

function Upgrader:client_onUpdate(dt)
    Belt.client_onUpdate(self, dt)
end

function Upgrader:cl_createUpgradeEffect()
    local size, offset = self:get_size_and_offset()
    local uuid, color

    local effect = self.data.effect
    if effect then
        local uid = effect.uuid
        if uid then uuid = sm.uuid.new(uid) end

        local clr = effect.color
        if clr then color = sm.color.new(clr.r, clr.g, clr.b) end
    else
        uuid = sm.uuid.new("5f41af56-df4c-4837-9b3c-10781335757f")
        color = sm.color.new(1, 1, 1)
    end

    if uuid then
        self.cl.effect = sm.effect.createEffect("ShapeRenderable", self.interactable)
        self.cl.effect:setParameter("uuid", uuid)
        self.cl.effect:setScale(size)
        self.cl.effect:setOffsetPosition(offset)
    else
        self.cl.effect = sm.effect.createEffect(effect.name, self.interactable)
    end

    self.cl.effect:setParameter("color", color)
    self.cl.effect:start()
end

function Upgrader:cl_toggleEffects(active)
    Belt.cl_toggleEffects(self, active)
    if active and not self.cl.effect:isPlaying() then
        self.cl.effect:start()
    else
        self.cl.effect:stop()
    end
end
