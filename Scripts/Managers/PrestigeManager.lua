dofile("$CONTENT_DATA/Scripts/util/util.lua")

---@class PrestigeManager : ScriptableObjectClass
PrestigeManager = class()
PrestigeManager.isSaveObject = true

function PrestigeManager:server_onCreate()
    self.sv = {}
    self.sv.saved = self.storage:load()

    if self.sv.saved == nil then
        self.sv.saved = {}
        self.sv.saved.prestige = 0
        self.sv.saved.lastPrestigeGain = 0
        self.sv.saved.specialItems = {}
    else
        self.sv.saved = unpackNetworkData(self.sv.saved)
    end

    if not g_prestigeManager then
        g_prestigeManager = self
    end
end

function PrestigeManager:server_onFixedUpdate()
    local tick = sm.game.getCurrentTick()

    if tick % 40 == 0 then
        self:sv_saveData()
    end

    if self.doPrestige and self.doPrestige < tick then
        self.doPrestige = nil
        if g_prestigeManager.getPrestigeGain() > 0 then
            self.spawnCrate = tick + 40 * 3
        end
        self:sv_doPrestige()
    end

    if self.spawnCrate and self.spawnCrate < tick then
        self.spawnCrate = nil
        local pos = sm.player.getAllPlayers()[1].character.worldPosition + sm.vec3.new(math.random(), math.random(), 10)
        LootCrateManager.sv_spawnCrate({
            pos = pos,
            uuid = obj_lootcrate_prestige,
            effect = "Woc - Destruct"
        })
    end
end

function PrestigeManager:sv_saveData()
    self.storage:save(packNetworkData(self.sv.saved))

    local clientData = {
        prestige = self.sv.saved.prestige,
        lastPrestigeGain = self.sv.saved.lastPrestigeGain
    }
    self.network:setClientData(packNetworkData(clientData))
end

function PrestigeManager.sv_addPrestige(prestige)
    g_prestigeManager.sv.saved.prestige = g_prestigeManager.sv.saved.prestige + prestige
end

function PrestigeManager.sv_setPrestige(prestige)
    g_prestigeManager.sv.saved.prestige = prestige
end

function PrestigeManager.sv_spendPrestige(prestige)
    if g_prestigeManager.sv.saved.prestige - prestige > 0 then
        g_prestigeManager.sv.saved.prestige = g_prestigeManager.sv.saved.prestige - prestige
        sm.event.sendToScriptableObject(g_prestigeManager.scriptableObject, "sv_saveData")
        return true
    end
    return false
end

function PrestigeManager.sv_addSpecialItem(uuid)
    local uuid = tostring(uuid)
    local quantity = g_prestigeManager.sv.saved.specialItems[uuid] or 0
    g_prestigeManager.sv.saved.specialItems[uuid] = math.min(quantity + 1, 65535)
    sm.event.sendToScriptableObject(g_prestigeManager.scriptableObject, "sv_saveData")
end

function PrestigeManager.sv_getSpecialItems()
    return (g_prestigeManager and g_prestigeManager.sv.saved.specialItems) or {}
end

function PrestigeManager.sv_prestige()
    sm.event.sendToPlayer(sm.player.getAllPlayers()[1], "sv_e_fadeToBlack", { duration = 1, timeout = 5 })
    sm.event.sendToPlayer(sm.player.getAllPlayers()[1], "sv_e_playEffect", { effect = "Prestige" })

    g_prestigeManager.doPrestige = sm.game.getCurrentTick() + 40
end

function PrestigeManager:sv_doPrestige()
    self.sv_addPrestige(self.getPrestigeGain())
    self.sv.saved.lastPrestigeGain = self.getPrestigeGain()

    self:sv_saveData()

    sm.event.sendToGame("sv_recreateWorld")

    MoneyManager.sv_setMoney(0)
    PollutionManager.sv_setPollution(0)
    sm.event.sendToScriptableObject(g_ResearchManager.scriptableObject, "sv_resetResearchProgress")
end

function PrestigeManager:client_onCreate()
    self.cl = {}
    self.cl.data = {}
    self.cl.data.prestige = 0
    self.cl.data.lastPrestigeGain = 0

    if not g_prestigeManager then
        g_prestigeManager = self
    end
end

function PrestigeManager:client_onClientDataUpdate(clientData)
    self.cl.data = unpackNetworkData(clientData)
end

function PrestigeManager:client_onFixedUpdate()
    self:updateHud()
end

function PrestigeManager:updateHud()
    if g_factoryHud then
        local prestige = self.getPrestigeGain()
        if prestige then
            g_factoryHud:setText("Prestige", format_number({ format = "prestige", value = prestige, prefix = "+ " }))
        end
    end
end

function PrestigeManager.getPrestigeGain()
    local money = MoneyManager.cl_getMoney()
    local minMoney = 1e9
    money = money - minMoney

    if money > 0 then
        return 2 ^ math.log(money, 10) / 100
    end
    return 0
end

function PrestigeManager.cl_e_getLastPrestigeGain()
    return g_prestigeManager.cl.data.lastPrestigeGain
end

function PrestigeManager.cl_getPrestige()
    return g_prestigeManager.sv and g_prestigeManager.sv.saved.prestige or g_prestigeManager.cl.data.prestige
end
