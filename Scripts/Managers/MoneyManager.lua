---Money is used to buy new items or exchange it for prestige points. It can be gained by selling items or drops.
---@class MoneyManager : ScriptableObjectClass
---@field sv MoneyManagerSv
---@field cl MoneyManagerCl
---@diagnostic disable-next-line: assign-type-mismatch
MoneyManager = class()
MoneyManager.isSaveObject = true

--------------------
-- #region Server
--------------------

local moneyCacheInterval = 60 --seconds

function MoneyManager:server_onCreate()
    g_moneyManager = g_moneyManager or self

    self.sv = {
        moneyEarnedSinceUpdate = 0,
        moneyEarnedCache = {},
        saved = self.storage:load()
    }

    if self.sv.saved == nil then
        self.sv.saved = {
            money = 0,
            moneyEarned = 0
        }
    else
        self.sv.saved = unpackNetworkData(self.sv.saved)
    end
end

function MoneyManager:server_onFixedUpdate()
    if sm.game.getCurrentTick() % 40 == 0 then
        self.storage:save(packNetworkData(self.sv.saved))

        local syncOffset = 3
        self.sv.moneyEarnedCache[math.floor(sm.game.getCurrentTick() / 40) % (moneyCacheInterval + syncOffset)] =
            self.sv.moneyEarnedSinceUpdate
        self.sv.moneyEarnedSinceUpdate = 0

        local moneyPerInterval = 0
        for k, money in pairs(self.sv.moneyEarnedCache) do
            moneyPerInterval = moneyPerInterval + money
        end

        local clientData = {
            money = self.sv.saved.money,
            moneyEarned = self.sv.saved.moneyEarned,
            moneyPerInterval = moneyPerInterval
        }
        self.network:setClientData(packNetworkData(clientData))
    end
end

---Adds money
---@param money number amount of money to add
---@param source "sellTool"|nil source that generated the money
function MoneyManager.sv_addMoney(money, source)
    g_moneyManager.sv.saved.money = g_moneyManager.sv.saved.money + money
    g_moneyManager.sv.saved.moneyEarned = g_moneyManager.sv.saved.moneyEarned + money

    if money > 0 and source ~= "sellTool" then
        g_moneyManager.sv.moneyEarnedSinceUpdate = g_moneyManager.sv.moneyEarnedSinceUpdate + money
        sm.event.sendToScriptableObject(g_tutorialManager.scriptableObject, "sv_e_questEvent", "MoneyMade")
    end


    if g_moneyManager.sv.saved.money >= 1e9 then
        sm.event.sendToScriptableObject(g_tutorialManager.scriptableObject, "sv_e_questEvent", "1BMoney")
    elseif g_moneyManager.sv.saved.money >= 100 then
        sm.event.sendToScriptableObject(g_tutorialManager.scriptableObject, "sv_e_questEvent", "100Money")
    end
end

function MoneyManager.sv_setMoney(money)
    g_moneyManager.sv.saved.money = money
    g_moneyManager.sv.saved.moneyEarned = money
    g_moneyManager:sv_resetMoneyCache()
end

---Try to spend money
---@param price number amount of money to spend
---@return boolean spent wheter the amount of money could be spent or not
function MoneyManager.sv_trySpendMoney(price)
    if price > g_moneyManager.sv.saved.money then
        return false
    else
        g_moneyManager.sv.saved.money = g_moneyManager.sv.saved.money - price
        return true
    end
end

function MoneyManager:sv_resetMoneyCache()
    self.sv.moneyEarnedSinceUpdate = 0
    self.sv.moneyEarnedCache = {}
end

-- #endregion

--------------------
-- #region Client
--------------------

function MoneyManager:client_onCreate()
    g_moneyManager = g_moneyManager or self

    self.cl = {
        data = {
            money = 0,
            moneyEarned = 0,
            moneyPerInterval = 0
        }
    }
end

function MoneyManager:client_onClientDataUpdate(clientData, channel)
    self.cl.data = unpackNetworkData(clientData)
end

function MoneyManager:client_onFixedUpdate()
    self:updateHud()
end

function MoneyManager:updateHud()
    if g_factoryHud then
        local money = self.getMoney()
        if money then
            g_factoryHud:setText("Money", format_number({ format = "money", value = money }))
            g_factoryHud:setText("Money/s",
                format_number({ format = "money", value = self.cl.data.moneyPerInterval, unit = "/min" }))
        end
    end
end

function MoneyManager.cl_moneyEarned()
    return g_moneyManager.cl.data.moneyEarned
end

-- #endregion

function MoneyManager.getMoney()
    return g_moneyManager.sv and g_moneyManager.sv.saved.money or g_moneyManager.cl.data.money
end

--------------------
-- #region Types
--------------------

--Types
---@class MoneyManagerSv
---@field moneyEarnedSinceUpdate number money earned since last money update
---@field moneyEarnedCache table<integer, number> table of money earned per ticks
---@field saved MoneyManagerSvSaved

---@class MoneyManagerSvSaved
---@field money number available money
---@field moneyEarned number total amount of money earned

---@class MoneyManagerCl
---@field money number available money
---@field moneyEarned number total amount of money earned
---@field moneyPerInterval number money earned per interval (used in HUD)
--TODO type fix

-- #endregion
