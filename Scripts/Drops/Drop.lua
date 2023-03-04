---A Drop is a shape dropped by droppers. It has a value that can be modified by upgraders and other things. It can be sold in a furnace to generate money.
---@class Drop : ShapeClass
---@field cl DropCl
---@field sv DropSv
---@diagnostic disable-next-line: assign-type-mismatch
Drop = class(nil)

---number of ores that exist at any given time
local oreCount = 0
---@type table<number, boolean> list of all drops that have been removed by a DropContainer during the tick
local storedDrops = {}

--------------------
-- #region Server
--------------------

---mark a drop as stored by drop container to avoid pollution from being released
---@param id number the shape id of the drop that was collected
function Drop:Sv_dropStored(id)
    storedDrops[id] = true
end

function Drop:server_onCreate()
    self:sv_init()
    self:sv_changeOreCount(1)

    --delete drop if it has been created before
    if not self.storage:load() then
        self.storage:save(true)
    else
        self.shape:destroyShape(0)
        return
    end
end

function Drop:sv_init()
    self.sv = {}
end

function Drop:server_onFixedUpdate()
    if sm.game.getCurrentTick() % 40 == 0 then
        self:sv_setClientData()
    end

    --cache server variables
    self.sv.cachedPos = self.shape.worldPosition
    self.sv.cachedPollution = self:getPollution()
    self.sv.cachedValue = self:getValue()
end

function Drop:server_onCollision(other, position, selfPointVelocity, otherPointVelocity, normal)
    --destroy drop when it hits terrain
    if not other then
        self.shape:destroyShape(0)
    end
end

function Drop:server_onDestroy()
    self:sv_changeOreCount(-1)

    if self:getPollution() then
        --prevent creating pollution from storing drops via DropContainer's
        if storedDrops[self.shape.id] then
            storedDrops[self.shape.id] = nil
            return
        end

        PollutionManager.sv_addPollution(self:getPollution())

        sm.event.sendToGame("sv_e_stonks",
            { pos = self.sv.cachedPos, value = tostring(self:getPollution()), format = "pollution", effect = "Pollution" })
    end
end

---update oreCount
---@param change number +1 or -1
function Drop:sv_changeOreCount(change)
    oreCount = oreCount + change
    if oreCount == 100 then
        sm.event.sendToScriptableObject(g_tutorialManager.scriptableObject, "sv_e_tryStartTutorial", "ClearOresTutorial")
    end
end

---sets the clientData
function Drop:sv_setClientData()
    local publicData = unpackNetworkData(self.interactable.publicData)
    if publicData then
        self.network:setClientData({
            value = publicData.value,
            pollution = publicData.pollution
        })
    end
end

---add an effect to a drop
---@param params effectParam
function Drop:sv_e_addEffect(params)
    self.network:sendToClients("cl_createEffect", params)
end

-- #endregion

--------------------
-- #region Client
--------------------

function Drop:client_onCreate()
    self:cl_init()

    --create default effect
    if self.data and self.data.effect then
        self:cl_createEffect({ key = "default", effect = self.data.effect })
    end
end

function Drop:cl_init()
    self.cl = {}

    self.cl.data = {}
    self.cl.data.value = 0

    self.cl.effects = {}
end

function Drop:client_onClientDataUpdate(data)
    self.cl.data = unpackNetworkData(data)

    --create default effect for pulluted ores
    if data.pollution and not self.cl.effects["pollution"] then
        self:cl_createEffect({ key = "pollution", effect = "Drops - Pollution" })
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
        local pollution = format_number({
            format = "pollution",
            value = self:getPollution(),
            color = "#9f4f9f"
        })

        sm.gui.setInteractionText("", o1 .. pollution .. o2)
        sm.gui.setInteractionText("#4f4f4f(" .. money .. "#4f4f4f)")
    else
        sm.gui.setInteractionText("", o1 .. money .. o2)
    end

    return true
end

---@param params effectParam
function Drop:cl_createEffect(params)
    local effect = sm.effect.createEffect(params.effect, self.interactable)

    if params.effect == "ShapeRenderable" then
        effect:setParameter("uuid", params.uuid)
        effect:setParameter("color", params.color or sm.color.new(1, 1, 1))
    end

    effect:setScale(params.scale or sm.vec3.one())
    effect:setOffsetPosition(params.offset or sm.vec3.zero())
    effect:setAutoPlay(true)
    effect:start()

    self.cl.effects[params.key] = effect
end

-- #endregion

---Returns the current value of a drop
---@return number
function Drop:getValue()
    local value = self.cl.data.value
    if sm.isServerMode() then
        value = (sm.exists(self.interactable) and self.interactable.publicData and self.interactable.publicData.value) or
            self.sv.cachedValue
    end
    return value
end

---Returns the current pollution value of a drop
---@return unknown pollution 0 or positive. nil if the drop has no pullution
function Drop:getPollution()
    local pollution = self.cl.data.pollution

    if sm.isServerMode() then
        ---@diagnostic disable-next-line:cast-local-type
        pollution = sm.exists(self.interactable) and self.interactable.publicData and
            self.interactable.publicData.pollution
        if not pollution then
            return self.sv.cachedPollution
        end

        sm.event.sendToScriptableObject(g_tutorialManager.scriptableObject, "sv_e_tryStartTutorial",
            "PollutionTutorial")
    end
    return (pollution and math.max(pollution - self:getValue(), 0)) or nil
end

--------------------
-- #region Types
--------------------

---@class DropSv
---@field cachedPos Vec3
---@field cachedPollution number
---@field cachedValue number
---@field pollution number
---@field value number

---@class effectParam
---@field key string key for the effect table
---@field effect string name of the effect
---@field uuid Uuid for ShapeRenderable
---@field color Color for ShapeRenderable
---@field scale Vec3 for ShapeRenderable
---@field offset Vec3 offsetPosition (defaults to sm.vec3.zero())

---@class DropCl
---@field data clientData
---@field effects table<string, Effect> all effects that are applied to a drop

---@class clientData
---@field pollution number
---@field value number

-- #endregion
