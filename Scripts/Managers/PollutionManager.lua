---@class PollutionManager:ScriptableObjectClass

dofile("$CONTENT_DATA/Scripts/util/util.lua")

PollutionManager = class()
PollutionManager.isSaveObject = true

function PollutionManager:server_onCreate()
    self.saved = self.storage:load()

    if self.saved == nil then
        self.saved = {}
        self.saved.pollution = 0
    else
        self.saved.pollution = tonumber(self.saved.pollution)
    end

    if not g_pollutionManager then
        g_pollutionManager = self
    end
end

function PollutionManager:server_onFixedUpdate()
    if sm.game.getCurrentTick() % 40 == 0 then
        local safeData = self.saved
		local pollution = safeData.pollution

		safeData.pollution = tostring(pollution)

		self.storage:save(self.saved)

		safeData.pollution = pollution

		self.network:setClientData({ pollution = tostring(self.saved.pollution)})
    end
end

function PollutionManager.sv_addPollution(pollution)
	g_pollutionManager.saved.pollution = g_pollutionManager.saved.pollution + pollution
end

function PollutionManager.sv_setPollution(pollution)
	g_pollutionManager.saved.pollution = pollution
end

function PollutionManager.sv_getPollution()
    return g_pollutionManager.saved.pollution
end

function PollutionManager:client_onCreate()
    self.cl = {}
    self.cl.pollution = 0

    if not g_pollutionManager then
        g_pollutionManager = self
    end
end

function PollutionManager:client_onClientDataUpdate(clientData, channel)
	self.cl.pollution = tonumber(clientData.pollution)
end

function PollutionManager:client_onFixedUpdate()
    self:updateHud()
end

function PollutionManager:client_onUpdate()
    if sm.isHost then
        self:updateHud()
    end
end

function PollutionManager:updateHud()
    if g_factoryHud then
        local pollution = self.saved and self.saved.pollution or self.cl.pollution
        if pollution then
            g_factoryHud:setText("Pollution", format_number({format = "pollution", value = pollution}))
        end
    end
end

function PollutionManager.cl_getPollution()
    return g_pollutionManager.saved and g_pollutionManager.saved.pollution or g_pollutionManager.cl.pollution
end

function PollutionManager.getResearchMultiplier()
    if g_pollutionManager.cl_getPollution() > 0 then
        return 2^math.log(g_pollutionManager.cl_getPollution(), 10)
    end
    return 1
end