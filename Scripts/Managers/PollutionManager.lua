---Pollution slows down research and triggers stronger raids. It can be produced by polluted drops. It is permanent and can only be reset via a prestige.
---@class PollutionManager : ScriptableObjectClass
---@field sv PollutionManagerSv
---@field cl PollutionManagerCl
PollutionManager = class()
PollutionManager.isSaveObject = true

--------------------
-- #region Server
--------------------

function PollutionManager:server_onCreate()
    g_pollutionManager = g_pollutionManager or self

    self.sv = {
        saved = self.storage:load()
    }

    if self.sv.saved == nil then
        self.sv.saved = { pollution = 0 }
    else
        self.sv.saved = unpackNetworkData(self.sv.saved)
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

-- #endregion

--------------------
-- #region Client
--------------------

function PollutionManager:client_onCreate()
    g_pollutionManager = g_pollutionManager or self

    self.cl = {
        data = { pollution = 0 }
    }
end

function PollutionManager:client_onClientDataUpdate(clientData)
    self.cl.data = unpackNetworkData(clientData)
end

function PollutionManager:client_onFixedUpdate()
    self:cl_updateHud()
end

function PollutionManager:client_onUpdate()
    if sm.isHost then
        self:cl_updateHud()
    end
end

function PollutionManager:cl_updateHud()
    if g_factoryHud then
        local pollution = self.getPollution()
        if pollution then
            g_factoryHud:setText("Pollution", format_number({ format = "pollution", value = pollution }))
        end
    end
end

-- #endregion

---Returns the multiplier by which research goals are increased due to pollution
---@return number multiplier the multiplier by which research goals are increased
function PollutionManager.getResearchMultiplier()
    if g_pollutionManager.getPollution() > 0 then
        return math.max(2 ^ math.log(g_pollutionManager.getPollution(), 10) *
            PerkManager.sv_getMultiplier("pollution"), 1)
    end
    return 1
end

function PollutionManager.getPollution()
    return g_pollutionManager.sv and g_pollutionManager.sv.saved.pollution or g_pollutionManager.cl.data.pollution
end

--------------------
-- #region Types
--------------------

---@class PollutionManagerSv
---@field saved PollutionManagerSvSaved

---@class PollutionManagerSvSaved
---@field pollution number pollution created in the world

---@class PollutionManagerCl
---@field data PollutionManagerClData

---@class PollutionManagerClData
---@field pollution number pollution created in the world

-- #endregion
