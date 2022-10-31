dofile("$CONTENT_DATA/Scripts/util/util.lua")

---@class PollutionManager : ScriptableObjectClass
---@field saved PollutionSaved
---@field cl PollutionCl
---@diagnostic disable-next-line: assign-type-mismatch
PollutionManager = class()
PollutionManager.isSaveObject = true

function PollutionManager:server_onCreate()
    self.sv = {}
    self.sv.saved = self.storage:load()

    if self.sv.saved == nil then
        self.sv.saved = {}
        self.sv.saved.pollution = 0
    else
        self.sv.saved = unpackNetworkData(self.sv.saved)
    end

    if not g_pollutionManager then
        g_pollutionManager = self
    end
end

function PollutionManager:server_onFixedUpdate()
    if sm.game.getCurrentTick() % 40 == 0 then
        self.storage:save(packNetworkData(self.sv.saved))

        self.network:setClientData({ pollution = tostring(self.sv.saved.pollution) })
    end
end

function PollutionManager.sv_addPollution(pollution)
    g_pollutionManager.sv.saved.pollution = g_pollutionManager.sv.saved.pollution + pollution
end

function PollutionManager.sv_setPollution(pollution)
    g_pollutionManager.sv.saved.pollution = pollution
end

function PollutionManager.sv_getPollution()
    return g_pollutionManager.sv.saved.pollution
end

function PollutionManager:client_onCreate()
    self.cl = {}
    self.cl.data = {}
    self.cl.data.pollution = 0

    if not g_pollutionManager then
        g_pollutionManager = self
    end
end

function PollutionManager:client_onClientDataUpdate(clientData, channel)
    self.cl.data = unpackNetworkData(clientData)
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
        local pollution = self.cl_getPollution()
        if pollution then
            g_factoryHud:setText("Pollution", format_number({ format = "pollution", value = pollution }))
        end
    end
end

function PollutionManager.cl_getPollution()
    return g_pollutionManager.sv.saved and g_pollutionManager.sv.saved.pollution or g_pollutionManager.cl.data.pollution
end

function PollutionManager.getResearchMultiplier()
    if g_pollutionManager.cl_getPollution() > 0 then
        return math.max(2 ^ math.log(g_pollutionManager.cl_getPollution(), 10) *
            PerkManager.sv_getMultiplier("pollution"), 1)
    end
    return 1
end

--Types
---@class PollutionCl
---@field pollution number

---@class PollutionSaved
---@field pollution number
