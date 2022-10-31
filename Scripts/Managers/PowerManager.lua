dofile("$CONTENT_DATA/Scripts/util/util.lua")

---@class PowerManager : ScriptableObjectClass
---@field sv PowerSv
---@field cl PowerCl
---@field loaded boolean
---@diagnostic disable-next-line: assign-type-mismatch
PowerManager = class()
PowerManager.isSaveObject = true

function PowerManager:server_onCreate()
    self.sv = {}
    self.sv.power = 0
    self.sv.powerLimit = 0

    self.sv.saved = self.storage:load()
    if self.sv.saved == nil then
        self.sv.saved = {}
        self.sv.saved.powerStored = 0
    else
        self.sv.saved = unpackNetworkData(self.sv.saved)
    end

    if not g_powerManager then
        g_powerManager = self
    end
end

function PowerManager:server_onFixedUpdate()
    if sm.game.getCurrentTick() % 40 == 0 then
        if self.cl.loaded and sm.game.getCurrentTick() > self.cl.loaded + 80 then
            self.sv.saved.powerStored = math.max(math.min(self.sv.powerLimit, self.sv.saved.powerStored + self.sv.power)
                , 0)
        end

        self.storage:save(packNetworkData(self.sv.saved))

        local clientData = { power = self.sv.power,
            powerLimit = self.sv.powerLimit,
            powerStored = self.sv.saved.powerStored }
        self.network:setClientData(packNetworkData(clientData))

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
    self.cl.data = {}
    self.cl.data.power = 0
    self.cl.data.powerLimit = 0
    self.cl.data.powerStored = 0

    if not g_powerManager then
        g_powerManager = self
    end

    self.cl.loaded = false
end

function PowerManager:client_onClientDataUpdate(clientData)
    self.cl.data = unpackNetworkData(clientData)
end

function PowerManager:client_onFixedUpdate()
    if g_factoryHud then
        local power = self.cl.data.power or 0
        local percentage = self.cl.data.powerStored > 0 and
            math.ceil((self.cl.data.powerStored / self.cl.data.powerLimit) * 100) or 0
        g_factoryHud:setText("Power",
            "#dddd00" .. format_number({ format = "energy", value = power }) .. " (" .. tostring(percentage) .. "%)")

        if power < 0 and self.cl.data.powerStored <= 0 then
            if self.cl.loaded and sm.game.getCurrentTick() > self.cl.loaded + 80 then
                sm.gui.displayAlertText("#{INFO_OUT_OF_ENERGY}", 1)
                sm.event.sendToPlayer(sm.localPlayer.getPlayer(), "cl_e_audio", "WeldTool - Error")
            end
        end
    end
end

function PowerManager.cl_setLoaded(loaded)
    g_powerManager.cl.loaded = loaded
end

function PowerManager.cl_getPowerStored()
    return g_powerManager.cl.data.powerStored
end

function PowerManager.cl_getPowerLimit()
    return g_powerManager.cl.data.powerLimit
end

--Types
---@class PowerSv
---@field power number
---@field powerLimit number
---@field saved PowerSvSaved

---@class PowerCl
---@field power number
---@field powerLimit number
---@field powerStored number

---@class PowerSvSaved
---@field powerStored number
