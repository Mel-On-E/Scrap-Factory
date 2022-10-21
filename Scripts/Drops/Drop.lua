Drop = class( nil )

local oreCount = 0
local lifeTime = 40*5--ticks

function Drop:server_onCreate()
    local body = self.shape:getBody()
    body:setErasable(false)
    body:setPaintable(false)
    body:setBuildable(false)
    body:setLiftable(false)
    self.timeout = 0
end

function Drop:server_onFixedUpdate()
    if self.shape:getVelocity():length() < 0.01 then
        self.timeout = self.timeout + 1
    else
        self.timeout = 0
    end

    if self.timeout > lifeTime then
        self.shape:destroyShape(0)
    end
    if sm.game.getCurrentTick() % 40 == 0 then
        local publicData = self.interactable.publicData
        if publicData then
            local params = {}
            params.value = tostring(publicData.value)
            if publicData.pollution then
                params.pollution = tostring(publicData.pollution)
            end
            self.network:setClientData(params)
        end
    end

    self.money = self.interactable.publicData.value
    self.pollution = self:getPollution()
    self.pos = self.shape.worldPosition
end

function Drop:server_onDestroy()
    if self.pollution then
        sm.event.sendToGame("sv_e_stonks", { pos = self.pos, value = tostring(self.pollution), format = "pollution", effect = "Pollution" })
        PollutionManager.sv_addPollution(self.pollution)
    end
end

function Drop:client_onCreate()
    oreCount = oreCount + 1
    if oreCount >= 100 then
        sm.event.sendToPlayer(sm.localPlayer.getPlayer(), "cl_e_drop_dropped")
    end
    self.cl = {}
    self.cl.value = 0
end

function Drop:client_onClientDataUpdate(data)
    self.cl.value = tonumber(data.value)
    if data.pollution then
        if not self.cl.pollution then
            sm.effect.playHostedEffect("Plants - Fertilizer", self.interactable)
        end
        self.cl.pollution = tonumber(data.pollution)
    end
end

function Drop:client_onDestroy()
    oreCount = oreCount - 1
end

function Drop:client_canInteract()
    local o1 = "<p textShadow='false' bg='gui_keybinds_bg_orange' color='#4f4f4f' spacing='9'>"
    local o2 = "</p>"
    local money = format_money({money = self.money or self.cl.value, color = "#4f9f4f"})
    if self.cl.pollution or self.pollution then
        local pollution = format_pollution({pollution = self.pollution or self:getPollution(), color = "#9f4f9f"})
        sm.gui.setInteractionText("", o1 .. pollution .. o2)
        sm.gui.setInteractionText("#4f4f4f(" .. money .. "#4f4f4f)")
    else
        sm.gui.setInteractionText("", o1 .. money .. o2)
    end
    return true
end

function Drop:getPollution()
    local value = self.cl.value
    local pollution = self.cl.pollution
    if sm.isServerMode() and self.interactable.publicData then
        value = self.interactable.publicData.value
        pollution = self.interactable.publicData.pollution
    end
    return pollution and math.max(pollution - value, 0) or nil
end