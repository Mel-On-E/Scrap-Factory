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
    local size = sm.vec3.new(self.data.box.x, self.data.box.y, self.data.box.z)
    local offset = sm.vec3.new(self.data.offset.x, self.data.offset.y, self.data.offset.z)
    self.trigger = sm.areaTrigger.createAttachedBox(self.interactable, size / 2, offset, sm.quat.identity(),
        sm.areaTrigger.filter.dynamicBody)
    self.trigger:bindOnEnter("sv_onEnter")
    self.trigger:bindOnStay("sv_onEnter")

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
            self.network:sendToClients("cl_toggle_effect", (g_research_furnace and true))
        end
    end
end

function Furnace:sv_onEnter(trigger, results)
    if not self.powerUtil.active then return end
    for _, result in ipairs(results) do
        if not sm.exists(result) then goto continue end
        for k, shape in pairs(result:getShapes()) do
            local interactable = shape:getInteractable()
            if not interactable then goto continue end
            local data = interactable:getPublicData()
            if not data or not data.value then goto continue end

            local value = self:sv_upgrade(shape)
            data.value = value

            if not data.pollution then
                if self.sv.saved.research then
                    value = value * PerkManager.sv_getMultiplier("research")
                    value = (ResearchManager.sv_addResearch(value, shape) and value) or 0
                    sm.event.sendToGame("sv_e_stonks",
                        { pos = shape:getWorldPosition(), value = tostring(value), format = "research", color = "#00dddd" })
                else
                    sm.event.sendToGame("sv_e_stonks",
                        { pos = shape:getWorldPosition(), value = tostring(value), format = "money" })
                    MoneyManager.sv_addMoney(value)
                end
            end

            shape.interactable.publicData.value = nil
            shape:destroyPart(0)
        end
        ::continue::
    end
end

function Furnace:sv_upgrade(shape)
    local value = shape.interactable.publicData.value
    if self.data.multiplier then
        value = value * self.data.multiplier
    end
    return value
end

function Furnace:sv_setResearch(uselessParameterThatOnlyExistsAsAPlaceholder, player)
    if not self.sv.saved.research then
        sm.event.sendToGame("sv_e_showTagMessage", { tag = "ResearchFurnaceSet", player = player })

        self.sv.saved.research = true
        self.storage:save(self.sv.saved)

        if g_research_furnace and type(g_research_furnace) == "Interactable" and sm.exists(g_research_furnace) then
            sm.event.sendToInteractable(g_research_furnace, "sv_removeResearch")
        end
        g_research_furnace = self.interactable
    else
        sm.event.sendToGame("sv_e_showTagMessage", { tag = "ResearchFurnaceRemoved", player = player })

        self.sv.saved.research = nil
        self.storage:save(self.sv.saved)

        g_research_furnace = nil
    end
    self.network:sendToClients("cl_toggle_effect", (g_research_furnace and true))
end

function Furnace:sv_removeResearch()
    self.sv.saved.research = nil
    self.storage:save(self.sv.saved)
end

function Furnace:client_onCreate()
    --[[
    local size = sm.vec3.new(self.data.box.x, self.data.box.y, self.data.box.z)
    local offset = sm.vec3.new(self.data.offset.x, self.data.offset.y, self.data.offset.z)

    self.effect = sm.effect.createEffect("ShapeRenderable", self.interactable)
	self.effect:setParameter("uuid", sm.uuid.new("5f41af56-df4c-4837-9b3c-10781335757f"))
	self.effect:setParameter("color", sm.color.new(1,1,1))
    self.effect:setScale(size)
    self.effect:setOffsetPosition(offset)
	self.effect:start()
    ]]
end

function Furnace:cl_toggle_effect(active)
    if cl_research_Effect and sm.exists(cl_research_Effect) then
        cl_research_Effect:destroy()
    end

    cl_research_Effect = sm.effect.createEffect("Buildarea - Oncreate", self.interactable)
    local size = sm.vec3.new(self.data.box.x, self.data.box.y * 6, self.data.box.z)
    cl_research_Effect:setScale(size / 18)
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
        self.network:sendToServer("sv_setResearch")
    end
end
