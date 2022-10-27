dofile("$CONTENT_DATA/Scripts/util/util.lua")

---@class PrestigeManager : ScriptableObjectClass
PrestigeManager = class()
PrestigeManager.isSaveObject = true

function PrestigeManager:server_onCreate()
    self.saved = self.storage:load()

    if self.saved == nil then
        self.saved = {}
        self.saved.prestige = 0
        self.saved.lastPrestigeGain = 0
        self.saved.specialItems = {}
    else
        self.saved.prestige = tonumber(self.saved.prestige)
    end

    if not g_prestigeManager then
        g_prestigeManager = self
    end
end

function PrestigeManager:server_onFixedUpdate()
    local tick = sm.game.getCurrentTick()

    if tick % 40 == 0 then
        self:sv_saveData()
        self.network:setClientData({ prestige = tostring(self.saved.prestige), lastPrestigeGain = tostring(self.saved.lastPrestigeGain) })
    end

    if self.doPrestige and self.doPrestige < tick then
        self.doPrestige = nil
        if g_prestigeManager.getPrestigeGain() >= 1 then
            self.spawnCrate = tick + 40*3
        end
        self:sv_doPrestige()
    end

    if self.spawnCrate and self.spawnCrate < tick then
        self.spawnCrate = nil
        local pos = sm.player.getAllPlayers()[1].character.worldPosition + sm.vec3.new(math.random(),math.random(),10)
        LootCrateManager.sv_spawnCrate({ pos = pos, uuid = obj_lootcrate_prestige,
            effect = "Woc - Destruct" })
    end
end

function PrestigeManager:sv_saveData()
    local safeData = self.saved
    local prestige = safeData.prestige
    local lastPrestigeGain = safeData.lastPrestigeGain

    safeData.prestige = tostring(prestige)
    safeData.lastPrestigeGain = tostring(lastPrestigeGain)

    self.storage:save(self.saved)

    safeData.prestige = prestige
    safeData.lastPrestigeGain = lastPrestigeGain
end

function PrestigeManager.sv_addPrestige(prestige)
    g_prestigeManager.saved.prestige = g_prestigeManager.saved.prestige + prestige
end

function PrestigeManager.sv_setPrestige(prestige)
    g_prestigeManager.saved.prestige = prestige
end

function PrestigeManager.sv_addSpecialItem(uuid)
    local uuid = tostring(uuid)
    local quantity = g_prestigeManager.saved.specialItems[uuid] or 0
    g_prestigeManager.saved.specialItems[uuid] = math.min(quantity+1, 999)
    sm.event.sendToScriptableObject(g_prestigeManager.scriptableObject, "sv_saveData")
end

function PrestigeManager.sv_getSpecialItems()
   return (g_prestigeManager and g_prestigeManager.saved.specialItems) or {}
end

function PrestigeManager.sv_prestige()
    sm.event.sendToPlayer(sm.player.getAllPlayers()[1], "sv_e_fadeToBlack", { duration = 1, timeout = 5 })
    sm.event.sendToPlayer(sm.player.getAllPlayers()[1], "sv_e_playEffect", { effect = "Prestige" })

    g_prestigeManager.doPrestige = sm.game.getCurrentTick() + 40
end

function PrestigeManager:sv_doPrestige()
    self.sv_addPrestige(self.getPrestigeGain())
    self.saved.lastPrestigeGain = self.getPrestigeGain()

    self:sv_saveData()

    sm.event.sendToGame("sv_recreateWorld")

    MoneyManager.sv_setMoney(0)
    PollutionManager.sv_setPollution(0)
    sm.event.sendToScriptableObject(g_ResearchManager.scriptableObject, "sv_resetResearch")
end

function PrestigeManager:client_onCreate()
    self.cl = {}
    self.cl.prestige = 0
    self.cl.lastPrestigeGain = 0

    if not g_prestigeManager then
        g_prestigeManager = self
    end
end

function PrestigeManager:client_onClientDataUpdate(clientData, channel)
    self.cl.prestige = tonumber(clientData.prestige)
    self.cl.lastPrestigeGain = tonumber(clientData.lastPrestigeGain)
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
            g_factoryHud:setText("Prestige", format_number({ format = "prestige", value = prestige, prefix = "+ " }))
        end
    end
end

function PrestigeManager.getPrestigeGain()
    local money = MoneyManager.cl_getMoney()
    local minMoney = 1e6
    money = money - minMoney

    if money > 0 then
        return 2 ^ math.log(money, 10) / 100
    end
    return 0
end

function PrestigeManager.cl_e_getLastPrestigeGain()
    return g_prestigeManager.cl.lastPrestigeGain
end

function PrestigeManager.cl_getPrestige()
    return g_prestigeManager.saved and g_prestigeManager.saved.prestige or g_prestigeManager.cl.prestige
end
