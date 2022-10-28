dofile("$CONTENT_DATA/Scripts/util/util.lua")

---@class MoneyManager : ScriptableObjectClass
---@field lastMoneyCache LastMoneyCache[] Used to calcuulate money/s
---@field lastMoney number Used to calc money/s
---@diagnostic disable-next-line: assign-type-mismatch
MoneyManager = class()
MoneyManager.isSaveObject = true

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
end

function MoneyManager.sv_spendMoney(price)
    if price > g_moneyManager.saved.money then
        return false
    else
        g_moneyManager.saved.money = g_moneyManager.saved.money - price
        return true
    end
end

function MoneyManager:client_onCreate()
    self.cl = {}
    self.cl.money = 0
    self.cl.moneyEarned = 0

    if not g_moneyManager then
        g_moneyManager = self
    end
    self.lastMoneyCache = {}
    self.lastMoney = 0
end

function MoneyManager:client_onClientDataUpdate(clientData, channel)
    self.cl.money = tonumber(clientData.money)
    self.cl.moneyEarned = tonumber(clientData.moneyEarned)
end

function MoneyManager:client_onFixedUpdate()
    self:updateHud()
    ---Money a sec

    if sm.game.getCurrentTick() % 20 == 0 then
        local money = self.cl_getMoney()

        if #self.lastMoneyCache < 50 then
            local moneyChange = money - self.lastMoney
            g_factoryHud:setText("Money/s", format_number({ format = "money", value = moneyChange }))

            table.insert(self.lastMoneyCache, { Money = money, LastMoney = self.lastMoney })
            self.lastMoney = money
            return
        end

        local moneyChange = 0

        for k, v in pairs(self.lastMoneyCache) do
            moneyChange = moneyChange + (v.Money - v.LastMoney)
        end

        g_factoryHud:setText("Money/s", format_number({ format = "money", value = (moneyChange / 50) * 2 }))

        table.insert(self.lastMoneyCache, { LastMoney = self.lastMoney, Money = money })
        table.remove(self.lastMoneyCache, 1)
        self.lastMoney = money
    end
end

function MoneyManager:client_onUpdate()
    if sm.isHost then
        self:updateHud()
    end
end

function MoneyManager:updateHud()
    if g_factoryHud then
        local money = self.cl_getMoney()
        if money then
            g_factoryHud:setText("Money", format_number({ format = "money", value = money }))
        end
    end
end

function MoneyManager.cl_getMoney()
    return g_moneyManager.saved and g_moneyManager.saved.money or g_moneyManager.cl.money
end

function MoneyManager.cl_moneyEarned()
    return g_moneyManager.cl.moneyEarned
end

--Types

---@class LastMoneyCache
---@field Money number
---@field LastMoney number
