---@class MoneyManager:ScriptableObjectClass

dofile("$CONTENT_DATA/Scripts/util/util.lua")

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

		self.network:setClientData({ money = tostring(self.saved.money)})
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

    if not g_moneyManager then
        g_moneyManager = self
    end
end

function MoneyManager:client_onClientDataUpdate(clientData, channel)
	self.cl.money = tonumber(clientData.money)
end

function MoneyManager:client_onFixedUpdate()
    self:updateHud()
end

function MoneyManager:client_onUpdate()
    if sm.isHost then
        self:updateHud()
    end
end

function MoneyManager:updateHud()
    if g_factoryHud then
        local money = self.saved and self.saved.money or self.cl.money
        if money then
            g_factoryHud:setText("Money", format_money({money = money}))
        end
    end
end