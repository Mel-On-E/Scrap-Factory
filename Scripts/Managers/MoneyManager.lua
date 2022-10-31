dofile("$CONTENT_DATA/Scripts/util/util.lua")

---@class MoneyManager : ScriptableObjectClass
---@field sv MoneySv
---@field cl MoneyCl
---@diagnostic disable-next-line: assign-type-mismatch
MoneyManager = class()
MoneyManager.isSaveObject = true

local moneyCacheInterval = 60 --seconds

function MoneyManager:server_onCreate()
    self.sv = {}
    self.sv.moneyEarned = 0
    self.sv.moneyEarnedCache = {}
    self.sv.saved = self.storage:load()

    if self.sv.saved == nil then
        self.sv.saved = {}
        self.sv.saved.money = 0
        self.sv.saved.moneyEarned = 0
    else
        ---@diagnostic disable-next-line: assign-type-mismatch
        self.sv.saved.money = tonumber(self.sv.saved.money)
        ---@diagnostic disable-next-line: assign-type-mismatch
        self.sv.saved.moneyEarned = tonumber(self.sv.saved.moneyEarned)
    end

    if not g_moneyManager then
        g_moneyManager = self
    end
end

function MoneyManager:server_onFixedUpdate()
    if sm.game.getCurrentTick() % 40 == 0 then
        local safeData = self.sv.saved
        local money = safeData.money
        local moneyEarned = safeData.moneyEarned

        ---@diagnostic disable-next-line: assign-type-mismatch
        safeData.money = tostring(money)
        ---@diagnostic disable-next-line: assign-type-mismatch
        safeData.moneyEarned = tostring(moneyEarned)

        self.storage:save(self.sv.saved)

        safeData.money = money
        safeData.moneyEarned = moneyEarned


        self.sv.moneyEarnedCache[#self.sv.moneyEarnedCache + 1] = self.sv.moneyEarned

        local newCache = {}
        local syncOffset = 3
        local resizeCache = (#self.sv.moneyEarnedCache > moneyCacheInterval + syncOffset and 1) or 0
        local moneyPerIntervall = 0
        for k, money in ipairs(self.sv.moneyEarnedCache) do
            if #newCache < moneyCacheInterval + syncOffset then
                newCache[#newCache + 1] = self.sv.moneyEarnedCache[k + resizeCache]
                moneyPerIntervall = moneyPerIntervall + money
            end
        end
        self.sv.moneyEarnedCache = newCache

        self.network:setClientData({ money = tostring(self.sv.saved.money),
            moneyEarned = tostring(self.sv.saved.moneyEarned),
            moneyPerIntervall = tostring(moneyPerIntervall) })
        self.sv.moneyEarned = 0
    end
end

function MoneyManager.sv_addMoney(money, source)
    g_moneyManager.sv.saved.money = g_moneyManager.sv.saved.money + money
    g_moneyManager.sv.saved.moneyEarned = g_moneyManager.sv.saved.moneyEarned + money

    if money > 0 and source ~= "sellTool" then
        g_moneyManager.sv.moneyEarned = g_moneyManager.sv.moneyEarned + money
    end
end

function MoneyManager.sv_setMoney(money)
    g_moneyManager.sv.saved.money = money
    g_moneyManager.sv.saved.moneyEarned = money
    g_moneyManager:sv_resetMoneyCache()
end

function MoneyManager.sv_spendMoney(price)
    if price > g_moneyManager.sv.saved.money then
        return false
    else
        g_moneyManager.sv.saved.money = g_moneyManager.sv.saved.money - price
        return true
    end
end

function MoneyManager:sv_resetMoneyCache()
    self.sv.oldMoneyEarned = nil
    self.sv.moneyEarned = 0
    self.sv.moneyEarnedCache = {}
end

function MoneyManager:client_onCreate()
    self.cl = {}
    self.cl.money = 0
    self.cl.moneyEarned = 0
    self.cl.moneyPerIntervall = 0

    if not g_moneyManager then
        g_moneyManager = self
    end
end

function MoneyManager:client_onClientDataUpdate(clientData, channel)
    ---@diagnostic disable-next-line: assign-type-mismatch
    self.cl.money = tonumber(clientData.money)
    ---@diagnostic disable-next-line: assign-type-mismatch
    self.cl.moneyEarned = tonumber(clientData.moneyEarned)
    ---@diagnostic disable-next-line: assign-type-mismatch
    self.cl.moneyPerIntervall = tonumber(clientData.moneyPerIntervall)
end

function MoneyManager:client_onFixedUpdate()
    self:updateHud()
end

function MoneyManager:updateHud()
    if g_factoryHud then
        local money = self.cl_getMoney()
        if money then
            g_factoryHud:setText("Money", format_number({ format = "money", value = money }))
            g_factoryHud:setText("Money/s",
                format_number({ format = "money", value = self.cl.moneyPerIntervall, unit = "/min" }))
        end
    end
end

function MoneyManager.cl_getMoney()
    return g_moneyManager.sv.saved and g_moneyManager.sv.saved.money or g_moneyManager.cl.money
end

function MoneyManager.cl_moneyEarned()
    return g_moneyManager.cl.moneyEarned
end

--Types
---@class MoneySv
---@field moneyEarned number
---@field moneyEarnedCache table
---@field saved MoneySvSaved

---@class MoneyCl
---@field money number
---@field moneyEarned number
---@field moneyPerIntervall number

---@class MoneySvSaved
---@field money number
---@field moneyEarned number
