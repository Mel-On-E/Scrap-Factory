---@class PowerManager:ScriptableObjectClass

dofile("$CONTENT_DATA/Scripts/util/util.lua")

PowerManager = class()
PowerManager.isSaveObject = true

function PowerManager:server_onCreate()
    self.sv = {}
    self.sv.saved = self.storage:load()

    if self.sv.saved == nil then
        self.sv.saved = {}
        self.sv.saved.powerStored = 0
    else
        self.sv.saved.powerStored = tonumber(self.sv.saved.powerStored)
    end

    self.sv.power = 0
    self.sv.powerLimit = 0

    if not g_powerManager then
        g_powerManager = self
    end
end

function PowerManager:server_onFixedUpdate()
    if sm.game.getCurrentTick() % 40 == 0 then
        local safeData = self.sv.saved
        local powerStored = safeData.powerStored

        if self.loaded and sm.game.getCurrentTick() > self.loaded + 80 then
			powerStored = math.max(math.min(self.sv.powerLimit, powerStored + self.sv.power), 0)
		end

		safeData.powerStored = tostring(powerStored)
		self.storage:save(self.sv.saved)
		safeData.powerStored = powerStored

		self.network:setClientData({ power = tostring(self.sv.power),
        powerLimit = tostring(self.sv.powerLimit),
        powerStored = tostring(self.sv.saved.powerStored)})

        self.sv.power = 0
    end
end

function PowerManager.sv_changePower(power)
    g_powerManager.sv.power = g_powerManager.sv.power + power
    return g_powerManager.sv.saved.powerStored + g_powerManager.sv.power > 0
end

function PowerManager.sv_changePowerLimit(powerLimit)
    g_powerManager.sv.powerLimit = g_powerManager.sv.powerLimit + powerLimit
    assert(g_powerManager.sv.powerLimit >= 0, "Powerlimit below zero!")
end

function PowerManager:client_onCreate()
    self.cl = {}
    self.cl.power = 0
    self.cl.powerLimit = 0
    self.cl.powerStored = 0

    if not g_powerManager then
        g_powerManager = self
    end

    self.loaded = false
end

function PowerManager:client_onClientDataUpdate(clientData)
	self.cl.power = tonumber(clientData.power)
    self.cl.powerLimit = tonumber(clientData.powerLimit)
    self.cl.powerStored = tonumber(clientData.powerStored)
end

function PowerManager:client_onFixedUpdate()
    if g_factoryHud then
        local power = self.cl.power or 0
		local percentage = self.cl.powerStored > 0 and math.ceil((self.cl.powerStored / self.cl.powerLimit) * 100) or 0
		g_factoryHud:setText("Power", "#dddd00" .. format_energy({power = power}) .. " (" .. tostring(percentage) .. "%)")

		if power < 0 and self.cl.powerStored <= 0 then
			if self.loaded and sm.game.getCurrentTick() > self.loaded + 80 then
				sm.gui.displayAlertText("#{INFO_OUT_OF_ENERGY}", 1)
				sm.event.sendToPlayer(sm.localPlayer.getPlayer(), "cl_e_audio", "WeldTool - Error")
			end
		end
    end
end

function PowerManager.cl_setLoaded(loaded)
    g_powerManager.loaded = loaded
end

function PowerManager.cl_getPowerStored()
    return g_powerManager.cl.powerStored
end

function PowerManager.cl_getPowerLimit()
    return g_powerManager.cl.powerLimit
end