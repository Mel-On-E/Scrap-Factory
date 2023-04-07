dofile("$SURVIVAL_DATA/Scripts/game/survival_loot.lua")

---A Teleporter will teleport drops to another Teleporter. There can only be 2 at a time.
---@class Teleporter : ShapeClass
---@field sv TeleporterSv
---@field cl TeleporterCl
---@field powerUtil PowerUtility
Teleporter = class()
Teleporter.maxParentCount = 1
Teleporter.maxChildCount = 0
Teleporter.connectionInput = sm.interactable.connectionType.logic
Teleporter.connectionOutput = sm.interactable.connectionType.none
Teleporter.colorNormal = sm.color.new(0xdf7f00ff)
Teleporter.colorHighlight = sm.color.new(0x2080ffff)

--------------------
-- #region Server
--------------------

local sv_portal_orange
local sv_portal_blue
local teleportedShapes = {}

function Teleporter:server_onCreate()
    ---@diagnostic disable-next-line: param-type-mismatch
    PowerUtility.sv_init(self)

    --save data
    self.sv = {}
    self.sv.saved = self.storage:load()
    if not self.sv.saved then
        self.sv.saved = {
            orange = false,
            blue = false
        }
    end

    --check if >2 portals
    if sv_portal_blue and sv_portal_orange then
        sm.event.sendToGame("sv_e_showTagMessage", { tag = "TeleporterMoreThan2" })
        SpawnLoot(sm.player.getAllPlayers()[1], { { uuid = self.shape.uuid } }, self.shape.worldPosition)
        self.shape:destroyShape(0)
        return
    end

    --assign portal
    if not sv_portal_orange and self.sv.saved.orange then
        sv_portal_orange = self
    elseif not sv_portal_blue and self.sv.saved.blue then
        sv_portal_blue = self
    elseif sv_portal_blue then
        sv_portal_orange = self
        self.sv.saved.orange = true
        self.sv.saved.blue = false
    else
        sv_portal_blue = self
        self.sv.saved.orange = false
        self.sv.saved.blue = true
    end

    self.storage:save(self.sv.saved)
    self.network:setClientData({ blue = self.sv.saved.blue, orange = self.sv.saved.orange })

    --create areaTrigger
    local size = sm.vec3.new(self.data.box.x, self.data.box.y, self.data.box.z)
    local offset = sm.vec3.new(self.data.offset.x, self.data.offset.y, self.data.offset.z)

    self.sv.trigger = sm.areaTrigger.createAttachedBox(self.interactable, size / 2, offset, sm.quat.identity(),
        sm.areaTrigger.filter.dynamicBody)
    self.sv.trigger:bindOnEnter("sv_onEnter")
end

function Teleporter:sv_onEnter(trigger, results)
    if not self.powerUtil.active then return end

    for _, result in ipairs(results) do
        if not sm.exists(result) then goto continue end

        for k, shape in pairs(result:getShapes()) do
            local interactable = shape:getInteractable()
            if not interactable then goto continue end
            if interactable.type ~= "scripted" then goto continue end

            local publicData = interactable:getPublicData()
            if not publicData or not publicData.value then goto continue end

            if teleportedShapes[shape.id] then goto continue end

            --valid drop entered
            self:sv_onEnterDrop(shape)
        end
        ::continue::
    end
end

---Called when a valid drop enters the portal and it has power
function Teleporter:sv_onEnterDrop(shape)
    if not (sv_portal_blue and sv_portal_orange) then return end

    local publicData = shape.interactable:getPublicData()

    local otherPortal = (self == sv_portal_blue and sv_portal_orange) or sv_portal_blue

    local offset = otherPortal.shape.at * 0.25
    ---@diagnostic disable-next-line: param-type-mismatch
    local newShape = sm.shape.createPart(shape.uuid, otherPortal.shape.worldPosition + offset,
        otherPortal.shape:getWorldRotation())
    newShape.interactable:setPublicData(publicData)

    shape:destroyPart(0)

    teleportedShapes[newShape.id] = sm.game.getCurrentTick() + 2
end

function Teleporter:server_onFixedUpdate()
    ---@diagnostic disable-next-line: param-type-mismatch
    PowerUtility.sv_fixedUpdate(self, "cl_toggleEffect")

    for id, tick in pairs(teleportedShapes) do
        if tick < sm.game.getCurrentTick() then
            teleportedShapes[id] = nil
        end
    end
end

function Teleporter:server_onDestroy()
    if sv_portal_blue == self then
        sv_portal_blue = nil
    elseif sv_portal_orange == self then
        sv_portal_orange = nil
    end
end

-- #endregion

--------------------
-- #region Client
--------------------

function Teleporter:client_onCreate()
    self.cl = {}

    --create portal area effect
    local size = sm.vec3.new(self.data.box.x, self.data.box.y * 7.5, self.data.box.z)
    local offset = sm.vec3.new(self.data.offset.x, self.data.offset.y, self.data.offset.z)

    self.cl.effect = sm.effect.createEffect("ShapeRenderable", self.interactable)
    self.cl.effect:setParameter("uuid", sm.uuid.new("f74a0354-05e9-411c-a8ba-75359449f770"))
    self.cl.effect:setScale(size / 4.5)
    self.cl.effect:setOffsetPosition(offset)
    local rot1 = sm.vec3.getRotation(sm.vec3.new(0, 0, 1), sm.vec3.new(0, 1, 0))

    --really fucking weird rotation offset thingy bc epic shader doesn't work on all rotations. WTF axolot why?
    local rot2 = self.shape.xAxis.y ~= 0 and sm.vec3.getRotation(sm.vec3.new(1, 0, 0), sm.vec3.new(0, 1, 0)) or
        sm.quat.identity()
    self.cl.effect:setOffsetRotation(rot1 * rot2)

    self.cl.effect:start()
end

function Teleporter:client_onClientDataUpdate(data)
    if data.blue then
        self:cl_setPortalAreaColor(sm.color.new(0x2080ffff))
    elseif data.orange then
        self:cl_setPortalAreaColor(sm.color.new(0xdf7f00ff))
    end
end

---toggles the effect of the portal area
function Teleporter:cl_toggleEffect(active)
    if active and not self.cl.effect:isPlaying() then
        self.cl.effect:start()
    else
        self.cl.effect:stop()
    end
end

---Changes the color of the portal effect
function Teleporter:cl_setPortalAreaColor(color)
    self.cl.effect:setParameter("color", color)
end

-- #endregion

--------------------
-- #region Types
--------------------

---@class TeleporterSv
---@field saved TeleporterSvSaved

---@class TeleporterSvSaved
---@field orange boolean whether this is an orange portal
---@field blue boolean whether this is a blue portal

---@class TeleporterCl
---@field effect Effect effect of the portal area

-- #endregion
