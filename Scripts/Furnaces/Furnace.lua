---@class Furnace : ShapeClass

dofile("$CONTENT_DATA/Scripts/util.lua")
dofile("$CONTENT_DATA/Scripts/util/power.lua")
dofile("$CONTENT_DATA/Scripts/Managers/LanguageManager.lua")


Furnace = class(Power)
Furnace.maxParentCount = 1
Furnace.maxChildCount = 0
Furnace.connectionInput = sm.interactable.connectionType.logic
Furnace.connectionOutput = sm.interactable.connectionType.none
Furnace.colorNormal = sm.color.new( 0x8000ddff )
Furnace.colorHighlight = sm.color.new( 0x8000ffff )

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
        else
            g_research_furnace = self
        end
    end
end

function Furnace:sv_onEnter(trigger, results)
    if not self.active then return end
    for _, result in ipairs(results) do
        if not sm.exists(result) then goto continue end
        for k, shape in pairs(result:getShapes()) do
            local interactable = shape:getInteractable()
            if not interactable then goto continue end
            local data = interactable:getPublicData()
            if not data or not data.value then goto continue end
            shape:destroyPart(0)

            if self.sv.saved.research then
                local value = (g_research[tostring(shape.uuid)] and data.value) or 0
                sm.event.sendToGame("sv_e_stonks", { pos = shape:getWorldPosition(), value = value, format = "research" })
                sm.event.sendToPlayer(sm.localPlayer,"cl_playFurnaceParticle", {pos = shape:getWorldPosition(), isResearch = self.sv.saved.research})
            else
                sm.event.sendToGame("sv_e_stonks", { pos = shape:getWorldPosition(), value = data.value, format = "money" })
                sm.event.sendToGame("sv_e_addMoney", tostring(data.value))
                sm.event.sendToPlayer("cl_playFurnaceParticle", {pos = shape:getWorldPosition(), isResearch = self.sv.saved.research})
            end      
        end
        ::continue::
    end
end

function Furnace:sv_setResearch(uselessParameterThatOnlyExistsAsAPlaceholder, player)
    if not self.sv.saved.research then
        sm.event.sendToGame("sv_e_showTagMessage", {tag = "ResearchFurnaceSet", player = player})
        
        self.sv.saved.research = true
        self.storage:save(self.sv.saved)

        if g_research_furnace and type(g_research_furnace) == "Interactable" then
            sm.event.sendToInteractable(g_research_furnace, "sv_removeResearch")
        end
        g_research_furnace = self.interactable
    else
        sm.event.sendToGame("sv_e_showTagMessage", {tag = "ResearchFurnaceRemoved", player = player})

        self.sv.saved.research = nil
        self.storage:save(self.sv.saved)

        g_research_furnace = nil
    end
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

function Furnace:client_canInteract()
	sm.gui.setInteractionText( "", sm.gui.getKeyBinding("Use", true), language_tag("SetResearchFurnace") )
    return true
end

function Furnace:client_onInteract(character, state)
    if state then
        self.network:sendToServer("sv_setResearch")
    end
end
