dofile("$CONTENT_DATA/Scripts/util/util.lua")
dofile("$CONTENT_DATA/Scripts/util/power.lua")
dofile("$CONTENT_DATA/Scripts/Managers/LanguageManager.lua")


---@class Furnace : Power
Furnace = class(Power)
Furnace.maxParentCount = 1
Furnace.maxChildCount = 0
Furnace.connectionInput = sm.interactable.connectionType.logic
Furnace.connectionOutput = sm.interactable.connectionType.none
Furnace.colorNormal = sm.color.new(0x8000ddff)
Furnace.colorHighlight = sm.color.new(0x8000ffff)

local cl_research_Effect

function Furnace:server_onCreate()
    sm.event.sendToScriptableObject(g_tutorialManager.scriptableObject, "sv_e_questEvent", "FurnacePlaced")

    Power.server_onCreate(self)

    self.sv = {}
    self.sv.saved = self.storage:load()
    if not self.sv.saved then
        self.sv.saved = {}
    else
        if g_research_furnace then
            self.sv.saved.research = nil
            self.storage:save(self.sv.saved)
        elseif self.sv.saved.research then
            g_research_furnace = self.interactable
            self.network:sendToClients("cl_toggle_research_effect", (g_research_furnace and true))
        end
    end

    local size = sm.vec3.new(self.data.box.x, self.data.box.y, self.data.box.z)
    local offset = sm.vec3.new(self.data.offset.x, self.data.offset.y, self.data.offset.z)

    self.sv.trigger = sm.areaTrigger.createAttachedBox(self.interactable, size / 2, offset, sm.quat.identity(),
        sm.areaTrigger.filter.dynamicBody)
    self.sv.trigger:bindOnEnter("sv_onEnter")
    self.sv.trigger:bindOnStay("sv_onEnter")
end

function Furnace:sv_onEnter(trigger, results)
    if not self.powerUtil.active then return end
    for _, result in ipairs(results) do
        if not sm.exists(result) then goto continue end

        for k, shape in pairs(result:getShapes()) do
            local interactable = shape:getInteractable()
            if not interactable then goto continue end

            local publicData = interactable:getPublicData()
            if not publicData or not publicData.value then goto continue end

            self:sv_onEnterDrop(shape)
        end
        ::continue::
    end
end

function Furnace:sv_onEnterDrop(shape)
    local value = self:sv_upgrade(shape)
    local publicData = shape.interactable:getPublicData()
    publicData.value = value

    if not publicData.pollution then
        if self.sv.saved.research then
            value = value * PerkManager.sv_getMultiplier("research")
            value = (ResearchManager.sv_addResearch(value, shape) and value) or 0
            sm.event.sendToGame("sv_e_stonks",
                { pos = shape:getWorldPosition(), value = tostring(value), format = "research", color = "#00dddd" })
        else
            sm.event.sendToGame("sv_e_stonks",
                { pos = shape:getWorldPosition(), value = tostring(value), format = "money" })
            MoneyManager.sv_addMoney(value)

            if next(publicData.upgrades) then
                sm.event.sendToScriptableObject(g_tutorialManager.scriptableObject, "sv_e_questEvent", "SellUpgradedDrop")
            end
        end
    end

    shape.interactable.publicData.value = nil
    shape:destroyPart(0)
end

function Furnace:sv_upgrade(shape)
    local value = shape.interactable.publicData.value
    if self.data.multiplier then
        value = value * self.data.multiplier
    end
    return value
end

function Furnace:sv_setResearch(_, player)
    sm.event.sendToGame("sv_e_showTagMessage",
        { tag = (self.sv.saved.research and "ResearchFurnaceRemoved") or "ResearchFurnaceSet", player = player })

    self.sv.saved.research = not self.sv.saved.research
    self.storage:save(self.sv.saved)

    if self.sv.saved.research then
        sm.event.sendToScriptableObject(g_tutorialManager.scriptableObject, "sv_e_questEvent", "ResearchFurnaceSet")

        if (g_research_furnace and type(g_research_furnace) == "Interactable" and sm.exists(g_research_furnace)) then
            sm.event.sendToInteractable(g_research_furnace, "sv_removeResearch")
        end
    end
    g_research_furnace = (self.sv.saved.research and self.interactable) or nil

    self.network:sendToClients("cl_toggle_research_effect", (g_research_furnace and true))
end

function Furnace:sv_removeResearch()
    self.sv.saved.research = nil
    self.storage:save(self.sv.saved)
end

function Furnace:client_onCreate()
    self.cl = {}
    local size = sm.vec3.new(self.data.box.x, self.data.box.y * 7.5, self.data.box.z)
    local offset = sm.vec3.new(self.data.offset.x, self.data.offset.y, self.data.offset.z)

    self.cl.effect = sm.effect.createEffect("ShapeRenderable", self.interactable)
    self.cl.effect:setParameter("uuid", sm.uuid.new("f74a0354-05e9-411c-a8ba-75359449f770"))
    self.cl.effect:setParameter("color", sm.color.new(0, 1, 0))
    self.cl.effect:setScale(size / 4.5)
    self.cl.effect:setOffsetPosition(offset)
    local rot1 = sm.vec3.getRotation(sm.vec3.new(0, 0, 1), sm.vec3.new(0, 1, 0))
    --really fucking weird rotation offset thingy bc epic shader doesn't work on all rotations. WTF axolot why?
    local rot2 = self.shape.xAxis.y ~= 0 and sm.vec3.getRotation(sm.vec3.new(1, 0, 0), sm.vec3.new(0, 1, 0)) or
        sm.quat.identity()
    self.cl.effect:setOffsetRotation(rot1 * rot2)

    self.cl.effect:start()
end

function Furnace:server_onFixedUpdate()
    Power.server_onFixedUpdate(self, "cl_toggleEffect")
end

function Furnace:cl_toggleEffect(active)
    if active and not self.cl.effect:isPlaying() then
        self.cl.effect:start()
    else
        self.cl.effect:stop()
    end
end

function Furnace:cl_toggle_research_effect(active)
    if cl_research_Effect and sm.exists(cl_research_Effect) then
        cl_research_Effect:destroy()
    end

    cl_research_Effect = sm.effect.createEffect("Builderguide - Background", self.interactable)

    local size = sm.vec3.new(self.data.box.x, self.data.box.y, self.data.box.z)
    cl_research_Effect:setScale(size)

    local offset = sm.vec3.new(self.data.offset.x, self.data.offset.y, self.data.offset.z)
    cl_research_Effect:setOffsetPosition(offset)

    if active then
        cl_research_Effect:start()
    end
end

function Furnace:client_canInteract()
    sm.gui.setInteractionText("", sm.gui.getKeyBinding("Use", true), language_tag("SetResearchFurnace"))
    return true
end

function Furnace:client_onInteract(character, state)
    if state then
        if TutorialManager.cl_getTutorialStep() > 7 then
            self.network:sendToServer("sv_setResearch")
        else
            sm.gui.displayAlertText(language_tag("TutorialLockedFeature"))
        end
    end
end
