Drop = class( nil )

local oreCount = 0
local lifeTime = 40*5--ticks

function Drop:server_onCreate()
    local body = self.shape:getBody()
    body:setErasable(false)
    body:setPaintable(false)
    body:setBuildable(false)
    body:setLiftable(false)
    self.interactable:setPublicData( {value = tonumber(self.data.value), upgrades = {}})
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
        self.network:setClientData({value = tostring(self.interactable.publicData.value)})
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
end

function Drop:client_onDestroy()
    oreCount = oreCount - 1
end

function Drop:client_canInteract()
    local o1 = "<p textShadow='false' bg='gui_keybinds_bg_orange' color='#4f4f4f' spacing='9'>"
    local o2 = "</p>"
    sm.gui.setInteractionText(language_tag("OreValue"), o1 .. format_money({money = self.cl.value, color = "#4f4f4f"}) .. o2)
    return true
end