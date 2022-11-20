---@class Drop : ShapeClass
---@field cl DropCl
---@field sv DropSv
---@diagnostic disable-next-line: assign-type-mismatch
Drop = class(nil)

local oreCount = 0

function Drop:server_onCreate()
    self:sv_init()
    self:sv_changeOreCount(1)
    self:sv_deleteSavedDrop()
end

function Drop:server_onFixedUpdate()
    if sm.game.getCurrentTick() % 40 == 0 then
        self:sv_setClientData()
    end

    --cache server variables
    self.sv.pos = self.shape.worldPosition
    self.sv.pollution = self:getPollution()
    self.sv.value = self:getValue()
end

function Drop:server_onDestroy()
    self:sv_changeOreCount(-1)

    if self:getPollution() then
        --ignore drops which are picked up by a dropContainer
        for _, id in pairs(g_deletedDrops.lastTick) do
            if self.shape:getId() == id then
                return
            end
        end

        sm.event.sendToGame("sv_e_stonks",
            { pos = self.sv.pos, value = tostring(self:getPollution()), format = "pollution", effect = "Pollution" })
        PollutionManager.sv_addPollution(self:getPollution())
    end
end

function Drop:server_onCollision(other, position, selfPointVelocity, otherPointVelocity, normal)
    --destroy drop when hit terrain
    if not other then
        self.shape:destroyShape(0)
    end
end

---initialize server variables
function Drop:sv_init()
    self.sv = {}
    self.sv.timeout = 0
end

---update oreCount
function Drop:sv_changeOreCount(change)
    oreCount = oreCount + change
    if oreCount == 100 then
        sm.event.sendToScriptableObject(g_tutorialManager.scriptableObject, "sv_e_tryStartTutorial", "ClearOresTutorial")
    end
end

---delete drop if it was created before
function Drop:sv_deleteSavedDrop()
    if not self.storage:load() then
        self.storage:save(true)
    else
        self.shape:destroyShape(0)
        return
    end
end

function Drop:sv_setClientData()
    local publicData = unpackNetworkData(self.interactable.publicData)
    if publicData then
        self.network:setClientData({
            value = publicData.value,
            pollution = publicData.pollution
        })
    end
end

---@class effectParam
---@field key string key for the effect table
---@field effect string name of the effect
---@field uuid Uuid for ShapeRenderable
---@field color Color for ShapeRenderable
---@field scale Vec3 for ShapeRenderable
---@field offset Vec3 offsetPosition (defaults to sm.vec3.zero())
---add an effect to a drop
---@param params effectParam
function Drop:sv_e_addEffect(params)
    self.network:sendToClients("cl_e_createEffect", params)
end

function Drop:client_onCreate()
    self:cl_init()

    if self.data and self.data.effect then
        self:cl_createEffect({ key = "default", effect = self.data.effect })
    end
end

function Drop:client_onClientDataUpdate(data)
    self.cl.data = unpackNetworkData(data)

    if data.pollution and not self.cl.effects["pollution"] then
        self:cl_createEffect({ key = "pollution", effect = "Ore Pollution" })
    end
end

function Drop:client_onDestroy()
    --destroy all effects
    for _, effect in pairs(self.cl.effects) do
        if sm.exists(effect) then
            effect:destroy()
        end
    end
end

function Drop:client_canInteract()
    --set interaction text
    local o1 = "<p textShadow='false' bg='gui_keybinds_bg_orange' color='#4f4f4f' spacing='9'>"
    local o2 = "</p>"
    local money = format_number({ format = "money", value = self:getValue(), color = "#4f9f4f" })

    if self:getPollution() then
        local pollution = format_number({ format = "pollution", value = self:getPollution(),
            color = "#9f4f9f" })

        sm.gui.setInteractionText("", o1 .. pollution .. o2)
        sm.gui.setInteractionText("#4f4f4f(" .. money .. "#4f4f4f)")
    else
        sm.gui.setInteractionText("", o1 .. money .. o2)
    end

    return true
end

function Drop:cl_init()
    self.cl = {}

    self.cl.data = {}
    self.cl.data.value = 0

    self.cl.effects = {}
end

---@param params effectParam
function Drop:cl_createEffect(params)
    local effect = sm.effect.createEffect(params.effect, self.interactable)

    if params.effect == "ShapeRenderable" then
        effect:setParameter("uuid", params.uuid)
        effect:setParameter("color", params.color)
        effect:setScale(params.scale)
    end

    effect:setOffsetPosition(params.offset or sm.vec3.zero())
    effect:setAutoPlay(true)
    effect:start()

    self.cl.effects[params.key] = effect
end

function Drop:getValue()
    local value = self.cl.data.value
    if sm.isServerMode() then
        value = (sm.exists(self.interactable) and self.interactable.publicData and self.interactable.publicData.value) or
            self.sv.value
    end
    return value
end

function Drop:getPollution()
    local pollution = self.cl.data.pollution
    if sm.isServerMode() then
        pollution = sm.exists(self.interactable) and self.interactable.publicData and
            self.interactable.publicData.pollution
        if not pollution then
            return self.sv.pollution
        end

        sm.event.sendToScriptableObject(g_tutorialManager.scriptableObject, "sv_e_tryStartTutorial",
            "PollutionTutorial")
    end
    return (pollution and math.max(pollution - self:getValue(), 0)) or nil
end

--Types

---@class DropSv
---@field timeout number
---@field pos Vec3
---@field pollution number
---@field value number


---@class DropCl
---@field data clientData
---@field effects table<string, Effect>

---@class clientData
---@field pollution number
---@field value number

---@class DropData
---@field effect string
