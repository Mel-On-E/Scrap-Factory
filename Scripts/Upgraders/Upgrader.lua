dofile("$CONTENT_DATA/Scripts/Other/Belt.lua")
---An Upgrader has an areaTrigger that interacts with a `Drop` and can modify its value. If `self.data.belt ~= nil`, it will also create a `Belt`.
---@class Upgrader : ShapeClass
---@field cl UpgraderCl
---@field data UpgraderData
---@field powerUtil PowerUtility
Upgrader = class()
Upgrader.maxParentCount = 1
Upgrader.maxChildCount = 0
Upgrader.connectionInput = sm.interactable.connectionType.logic
Upgrader.connectionOutput = sm.interactable.connectionType.none
Upgrader.colorNormal = sm.color.new(0x00dd00ff)
Upgrader.colorHighlight = sm.color.new(0x00ff00ff)

--------------------
-- #region Server
--------------------

---@class UpgraderParams
---@field filters number|nil filters of the areaTrigger
---@param params UpgraderParams
function Upgrader:server_onCreate(params)
    ---@diagnostic disable-next-line: param-type-mismatch
    PowerUtility.sv_init(self)

    if self.data.belt then
        ---@diagnostic disable-next-line: param-type-mismatch
        Belt.server_onCreate(self)
        self.sv_onStay = Belt.sv_onStay
    end

    self.data.upgrade = unpackNetworkData(self.data.upgrade)

    --create areaTrigger
    params = params or {}
    local size, offset = self:get_size_and_offset()

    self.upgradeTrigger = sm.areaTrigger.createAttachedBox(self.interactable, size / 2, offset, sm.quat.identity(),
        params.filters or sm.areaTrigger.filter.dynamicBody)
    self.upgradeTrigger:bindOnEnter("sv_onEnter")
end

function Upgrader:server_onFixedUpdate()
    if self.data.belt then
        ---@diagnostic disable-next-line: param-type-mismatch
        Belt.server_onFixedUpdate(self)
    else
        ---@diagnostic disable-next-line: param-type-mismatch
        PowerUtility.sv_fixedUpdate(self, "cl_toggleEffects")
    end
end

function Upgrader:sv_onEnter(trigger, results)
    if not self.powerUtil.active then return end

    for _, result in ipairs(results) do
        if not sm.exists(result) then goto continue end
        if type(result) ~= "Body" then goto continue end

        for k, shape in ipairs(result:getShapes()) do
            local interactable = shape:getInteractable()
            if not interactable then goto continue end
            if interactable.type ~= "scripted" then goto continue end

            local data = interactable:getPublicData()
            if not data or not data.value then goto continue end

            local uuid = tostring(self.shape.uuid)
            if self.data.upgrade.cap and data.value > self.data.upgrade.cap then goto continue end
            if self.data.upgrade.limit and data.upgrades[uuid] and data.upgrades[uuid] >= self.data.upgrade.limit then goto continue end

            --valid drop
            self:sv_onUpgrade(shape, data)
        end
        ::continue::
    end
end

---Upgrade a drop shape
---@param shape Shape the shape to be upgraded
---@param data table the public data of the shape to be upgraded
function Upgrader:sv_onUpgrade(shape, data)
    local uuid = tostring(self.shape.uuid)

    data.upgrades[uuid] = data.upgrades[uuid] and data.upgrades[uuid] + 1 or 1
    shape.interactable:setPublicData(data)

    local effectParams = {}
    if uuid == "17de8088-d5a8-45b1-80eb-1d0688a8c39a" then
        effectParams = {
            effect = "Upgraders - Random",
            pos = shape.worldPosition,
            host = shape
        }
    else
        effectParams = {
            effect = "Upgraders - Basic",
            pos = shape.worldPosition,
            host = shape
        }
    end
    sm.event.sendToPlayer(sm.player.getAllPlayers()[1], "sv_e_playEffect", effectParams)
end

-- #endregion

--------------------
-- #region Client
--------------------

function Upgrader:client_onCreate()
    self.cl = {}

    if self.data.belt then
        ---@diagnostic disable-next-line: param-type-mismatch
        Belt.client_onCreate(self)
    end

    self:cl_createUpgradeEffect()
end

function Upgrader:client_onUpdate(dt)
    if self.data.belt then
        ---@diagnostic disable-next-line: param-type-mismatch
        Belt.client_onUpdate(self, dt)
    end
end

---create effect to visualize the upgrade areaTrigger
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

---toggle the effects depending on the current power state
function Upgrader:cl_toggleEffects(active)
    ---@diagnostic disable-next-line: param-type-mismatch
    Belt.cl_toggleEffects(self, active)
    if active and not self.cl.effect:isPlaying() then
        self.cl.effect:start()
    else
        self.cl.effect:stop()
    end
end

-- #endregion

---get the size and offset for the areaTrigger based on the script data
---@return Vec3 size
---@return Vec3 offset
function Upgrader:get_size_and_offset()
    local size = sm.vec3.new(self.data.upgrade.box.x, self.data.upgrade.box.y, self.data.upgrade.box.z)
    local offset = sm.vec3.new(self.data.upgrade.offset.x, self.data.upgrade.offset.y, self.data.upgrade.offset.z)
    return size, offset
end

--------------------
-- #region Types
--------------------

---@class UpgraderData
---@field belt boolean wether the Upgrader has a belt or not
---@field upgrade UpgraderUpgrade the upgrade data of the Upgrader
---@field effect UpgraderDataEffect

---@class UpgraderUpgrade
---@field cap number|nil the upgrader can only upgrade drops under this limit
---@field limit number|nil the maximum amount of times this upgrader can be applied to a drop
---@field box table<string, number> dimensions x, y, z for the areaTrigger
---@field offset table<string, number> offset x, y, z for the areaTrigger

---@class UpgraderDataEffect
---@field name string the name of the upgrade effect
---@field color table<string, number> r, g, b values for the color of the effect
---@field uuid string uuid used for ShapeRenderable effect

---@class UpgraderCl
---@field effect Effect the effect that visualizes the areaTrigger of the Upgrader

-- #endregion
