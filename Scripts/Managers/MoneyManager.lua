dofile("$CONTENT_DATA/Scripts/util/util.lua")

---@class MoneyManager : ScriptableObjectClass
---@field lastMoneyCache LastMoneyCache[] Used to calcuulate money/s
---@field lastMoney number Used to calc money/s
---@diagnostic disable-next-line: assign-type-mismatch
MoneyManager = class()
MoneyManager.isSaveObject = true

local moneyCacheInterval = 40*60 --ticks

function MoneyManager:server_onCreate()
    self.saved = self.storage:load()

    if self.saved == nil then
        self.saved = {}
        self.saved.money = 0
        self.saved.moneyEarned = 0
    else
        self.saved.money = tonumber(self.saved.money)
        self.saved.moneyEarned = tonumber(self.saved.moneyEarned)
    end

    if not g_moneyManager then
        g_moneyManager = self
    end
end

function MoneyManager:server_onFixedUpdate()
    if sm.game.getCurrentTick() % 40 == 0 then
        local safeData = self.saved
        local money = safeData.money
        local moneyEarned = safeData.moneyEarned

        safeData.money = tostring(money)
        safeData.moneyEarned = tostring(moneyEarned)

        self.storage:save(self.saved)

        safeData.money = money
        safeData.moneyEarned = moneyEarned

        self.network:setClientData({ money = tostring(self.saved.money), moneyEarned = tostring(self.saved.moneyEarned) })
    end
end

function MoneyManager.sv_addMoney(money)
    g_moneyManager.saved.money = g_moneyManager.saved.money + money
    g_moneyManager.saved.moneyEarned = g_moneyManager.saved.moneyEarned + money
end

function MoneyManager.sv_setMoney(money)
    g_moneyManager.saved.money = money
    g_moneyManager.saved.moneyEarned = money
    sm.event.sendToScriptableObject(g_moneyManager.scriptableObject, "sv_resetMoneyCache")
end

function MoneyManager.sv_spendMoney(price)
    if price > g_moneyManager.saved.money then
        return false
    else
        g_moneyManager.saved.money = g_moneyManager.saved.money - price
        return true
    end
end

function MoneyManager:sv_resetMoneyCache()
    self.network:sendToClients("cl_resetMoneyCache")
end

function MoneyManager:client_onCreate()
    self.cl = {}
    self.cl.money = 0
    self.cl.moneyEarned = 0
    self.cl.moneyEarnedCache = {}
    self.cl.moneyPerIntervall = 0

    if not g_moneyManager then
        g_moneyManager = self
    end
end

function MoneyManager:client_onClientDataUpdate(clientData, channel)
    self.cl.money = tonumber(clientData.money)

    local newMoneyEarned = tonumber(clientData.moneyEarned)
    local moneyDuringIntervall = newMoneyEarned - ((#self.cl.moneyEarnedCache == 0 and newMoneyEarned) or self.cl.moneyEarned)

    self.cl.moneyEarnedCache[#self.cl.moneyEarnedCache+1] = {money = moneyDuringIntervall, tick = sm.game.getCurrentTick()}

    self.cl.moneyEarned = newMoneyEarned
end

function MoneyManager:client_onFixedUpdate()
    self:updateHud()

    local newCache = {}
    self.cl.moneyPerIntervall = 0
    for _, cache in ipairs(self.cl.moneyEarnedCache) do
        if sm.game.getCurrentTick() - cache.tick < moneyCacheInterval + 80 then
            self.cl.moneyPerIntervall = self.cl.moneyPerIntervall + cache.money
            newCache[#newCache+1] = cache
        end
    end
    self.cl.moneyEarnedCache = newCache
end

function MoneyManager:updateHud()
    if g_factoryHud then
        local money = self.cl_getMoney()
        if money then
            g_factoryHud:setText("Money", format_number({ format = "money", value = money }))
            g_factoryHud:setText("Money/s", format_number({ format = "money", value = (self.cl.moneyPerIntervall/moneyCacheInterval)*40, unit = "/min" }))
        end
    end
end

function MoneyManager.cl_getMoney()
    return g_moneyManager.saved and g_moneyManager.saved.money or g_moneyManager.cl.money
end

function MoneyManager.cl_moneyEarned()
    return g_moneyManager.cl.moneyEarned
end

function MoneyManager:cl_resetMoneyCache()
    self.cl.moneyEarnedCache = {}
end

--Types

---@class LastMoneyCache
---@field Money number
---@field LastMoney number
