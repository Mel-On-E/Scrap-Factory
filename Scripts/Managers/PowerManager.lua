---@class PowerManager : ScriptableObjectClass
---@field sv PowerManagerSv
---@field cl PowerManagerCl
PowerManager = class()
PowerManager.isSaveObject = true

--------------------
-- #region Server
--------------------

function PowerManager:server_onCreate()
    g_powerManager = g_powerManager or self

    self.sv = {
        power = 0,
        powerStorage = 0,
        saved = self.storage:load()
    }
    
    if self.sv.saved == nil then
        self.sv.saved = { powerStored = 0 }
    else
        self.sv.saved = unpackNetworkData(self.sv.saved)
    end
end

function PowerManager:server_onFixedUpdate()
    if sm.game.getCurrentTick() % 40 == 0 then
        if self.cl.loadTick and sm.game.getCurrentTick() > self.cl.loadTick + 80 then
            self.sv.saved.powerStored = math.max(
                math.min(self.sv.powerStorage, self.sv.saved.powerStored + self.sv.power)
                , 0)
        end

        self.storage:save(packNetworkData(self.sv.saved))

        local clientData = {
            power = self.sv.power,
            powerStorage = self.sv.powerStorage,
            powerStored = self.sv.saved.powerStored
        }
        self.network:setClientData(packNetworkData(clientData))

        self.sv.power = 0
    end
end

---change the power currently available
---@param power number how the available power changes
---@return boolean powerGain true if there is no power deficit
function PowerManager.sv_changePower(power)
    g_powerManager.sv.power = g_powerManager.sv.power + power
    return g_powerManager.sv.saved.powerStored + g_powerManager.sv.power >= 0
end

---change the storage capacity
---@param powerStorage number how the available storage changes
function PowerManager.sv_changePowerStorage(powerStorage)
    g_powerManager.sv.powerStorage = g_powerManager.sv.powerStorage + powerStorage
    assert(g_powerManager.sv.powerStorage >= 0, "powerStorage below zero!")
end

-- #endregion

--------------------
-- #region Client
--------------------

function PowerManager:client_onCreate()
    g_powerManager = g_powerManager or self

    self.cl = {
        data = {
            power = 0,
            powerStorage = 0,
            powerStored = 0
        },
        lastWarningPlayed = 0
    }
end

function PowerManager:client_onClientDataUpdate(clientData)
    self.cl.data = unpackNetworkData(clientData)
end

function PowerManager:client_onFixedUpdate()
    if g_factoryHud then
        local power = self.cl.data.power or 0
        local percentage = self.cl.data.powerStored > 0 and
            math.ceil((self.cl.data.powerStored / self.cl.data.powerStorage) * 100) or 0
        g_factoryHud:setText("Power",
            "#dddd00" .. format_number({ format = "power", value = power }) .. " (" .. tostring(percentage) .. "%)")

        if power < 0 and self.cl.data.powerStored <= 0 then
            if sm.game.getCurrentTick() - self.cl.lastWarningPlayed >= 40
                and (self.cl.loadTick and sm.game.getCurrentTick() > self.cl.loadTick + 80) then
                sm.gui.displayAlertText("#{INFO_OUT_OF_ENERGY}", 1)
                sm.event.sendToPlayer(sm.localPlayer.getPlayer(), "cl_e_playAudio", "WeldTool - Error")
                self.cl.lastWarningPlayed = sm.game.getCurrentTick()
            end
        end
    end
end

function PowerManager.cl_setloadTick(loadTick)
    g_powerManager.cl.loadTick = loadTick
end

function PowerManager.cl_getPowerStored()
    return g_powerManager.cl.data.powerStored
end

function PowerManager.cl_getPowerStorage()
    return g_powerManager.cl.data.powerStorage
end

-- #endregion

--------------------
-- #region Types
--------------------

---@class PowerManagerSv
---@field power number amount of power available
---@field powerStorage number max amount of power that can be stored
---@field saved PowerManagerSvSaved

---@class PowerManagerCl
---@field loadTick integer tick at which the power PowerManager has been loaded
---@field lastWarningPlayed integer tick at which the last out of power warning was played
---@field data PowerManagerClData

---@class PowerManagerClData
---@field power number amount of power available
---@field powerStorage number max amount of power that can be stored
---@field powerStored number power stored in batteries and such

---@class PowerManagerSvSaved
---@field powerStored number power stored in batteries and such

-- #endregion
