---@class PrestigeManager:ScriptableObjectClass

dofile("$CONTENT_DATA/Scripts/util/util.lua")

PrestigeManager = class()
PrestigeManager.isSaveObject = true

function PrestigeManager:server_onCreate()
    self.saved = self.storage:load()

    if self.saved == nil then
        self.saved = {}
        self.saved.prestige = 0
    else
        self.saved.prestige = tonumber(self.saved.prestige)
    end

    if not g_prestigeManager then
        g_prestigeManager = self
    end
end

function PrestigeManager:server_onFixedUpdate()
    if sm.game.getCurrentTick() % 40 == 0 then
        local safeData = self.saved
		local prestige = safeData.prestige

		safeData.prestige = tostring(prestige)

		self.storage:save(self.saved)

		safeData.prestige = prestige

		self.network:setClientData({ prestige = tostring(self.saved.prestige)})
    end
end

function PrestigeManager.sv_addPrestige(prestige)
	g_prestigeManager.saved.prestige = g_prestigeManager.saved.prestige + prestige
end

function PrestigeManager.sv_setPrestige(prestige)
	g_prestigeManager.saved.prestige = prestige
end

function PrestigeManager.sv_getPrestige()
    return g_prestigeManager.saved.prestige
end

function PrestigeManager:client_onCreate()
    self.cl = {}
    self.cl.prestige = 0

    if not g_prestigeManager then
        g_prestigeManager = self
    end
end

function PrestigeManager:client_onClientDataUpdate(clientData, channel)
	self.cl.prestige = tonumber(clientData.prestige)
end

function PrestigeManager:client_onFixedUpdate()
    self:updateHud()
end

function PrestigeManager:client_onUpdate()
    if sm.isHost then
        self:updateHud()
    end
end

function PrestigeManager:updateHud()
    if g_factoryHud then
        local prestige = self.getPrestigeGain()
        if prestige then
            g_factoryHud:setText("Prestige", format_number({format = "prestige", value = prestige}))
        end
    end
end

function PrestigeManager.getPrestigeGain()
    local money = MoneyManager.cl_getMoney()
    local minMoney = 1e6
    money = money - minMoney

    if money > 0 then
        return 2^math.log(money, 10) / 100
    end
    return 0
end

function PrestigeManager.cl_getPrestige()
    return g_prestigeManager.saved and g_prestigeManager.saved.prestige or g_prestigeManager.cl.prestige
end