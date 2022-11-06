---@class Drop : ShapeClass
Drop = class(nil)

local oreCount = 0
local lifeTime = 40 * 5 --ticks

function Drop:server_onCreate()
    oreCount = oreCount + 1
    if oreCount >= 100 then
        sm.event.sendToScriptableObject(g_tutorialManager.scriptableObject, "sv_e_tryStartTutorial", "ClearOresTutorial")
    end

    self.sv = {}
    self.sv.timeout = 0

    if not self.storage:load() then
        self.storage:save(true)
    else
        self.shape:destroyShape(0)
        return
    end

    local body = self.shape:getBody()
    body:setErasable(false)
    body:setPaintable(false)
    body:setBuildable(false)
    body:setLiftable(false)
end

function Drop:server_onFixedUpdate()
    if self.shape:getVelocity():length() < 0.01 then
        self.sv.timeout = self.sv.timeout + 1
    else
        self.sv.timeout = 0
    end

    if self.sv.timeout > lifeTime then
        self.shape:destroyShape(0)
    end

    if sm.game.getCurrentTick() % 40 == 0 then
        local publicData = unpackNetworkData(self.interactable.publicData)
        if publicData then
            self.network:setClientData({
                value = publicData.value,
                pollution = publicData.pollution
            })
        end
    end

    self.sv.pos = self.shape.worldPosition
    self.sv.pollution = self:getPollution()
    self.sv.value = self:getValue()
end

function Drop:server_onDestroy()
    oreCount = oreCount - 1

    if self:getPollution() then
        sm.event.sendToGame("sv_e_stonks",
            { pos = self.sv.pos, value = tostring(self:getPollution()), format = "pollution", effect = "Pollution" })
        PollutionManager.sv_addPollution(self:getPollution())
    end
end

function Drop:client_onCreate()
    self.cl = {}
    self.cl.value = 0
    self.cl.effects = {}

    if self.data and self.data.effect then
        self:cl_createEffect("default", self.data.effect)
    end
end

function Drop:cl_createEffect(key, name)
    self.cl.effects[key] = sm.effect.createEffect(name, self.interactable)
    self.cl.effects[key]:setAutoPlay(true)
    self.cl.effects[key]:start()
end

function Drop:client_onClientDataUpdate(data)
    data = unpackNetworkData(data)
    self.cl.value = data.value
    self.cl.pollution = data.pollution

    if data.pollution and not self.cl.pollutionEffect then
        self:cl_createEffect("pollution", "Ore Pollution")
    end
end

function Drop:client_onDestroy()
    for _, effect in pairs(self.cl.effects) do
        if sm.exists(effect) then
            effect:destroy()
        end
    end
end

function Drop:client_canInteract()
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

function Drop:getValue()
    local value = self.cl.value
    if sm.isServerMode() then
        value = (sm.exists(self.interactable) and self.interactable.publicData.value) or self.sv.value
    end
    return value
end

function Drop:getPollution()
    local pollution = self.cl.pollution
    if sm.isServerMode() then
        pollution = sm.exists(self.interactable) and self.interactable.publicData.pollution
        if not pollution then
            return self.sv.pollution
        end
    end
    return (pollution and math.max(pollution - self:getValue(), 0)) or nil
end
