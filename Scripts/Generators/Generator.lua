dofile("$CONTENT_DATA/Scripts/util/util.lua")

Generator = class( nil )

function Generator:server_onCreate()
    if self.data.power then
        self.data.power = tonumber(self.data.power)
    end

    if self.data.powerLimit then
        self.data.powerLimit = tonumber(self.data.powerLimit)
        PowerManager.sv_changePowerLimit(self.data.powerLimit)
    end
end

function Generator:server_onDestroy()
    if self.data.powerLimit then
        PowerManager.sv_changePowerLimit(-self.data.powerLimit)
    end
end

function Generator:server_onFixedUpdate()
    if self.data.power and sm.game.getCurrentTick() % 40 == 0 then
        local power = self:getPower()
        PowerManager.sv_changePower(power)
        self.network:setClientData({power = power})
    end
end

function Generator:getPower()
    print(self.data.power)
    return self.data.power
end

function Generator:client_onCreate()
    self.cl = {}
    self.cl.power = 0
end

function Generator:client_onClientDataUpdate(data)
    self.cl.power = data.power
end

function Generator:client_canInteract()
    local o1 = "<p textShadow='false' bg='gui_keybinds_bg_orange' color='#4f4f4f' spacing='9'>"
    local o2 = "</p>"
    sm.gui.setInteractionText(language_tag("PowerOutput"), o1 .. format_number({format = "energy", value = self.cl.power, color = "#4f4f4f"}) .. o2)
    return true
end