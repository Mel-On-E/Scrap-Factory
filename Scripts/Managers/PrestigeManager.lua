---Prestige is a currency gained by resetting the some of your progress. It can be used to unlock stuff to gain even more prestige.
---@class PrestigeManager : ScriptableObjectClass
---@field sv PrestigeManagerSv
---@field cl PrestigeManagerCl
PrestigeManager = class()
PrestigeManager.isSaveObject = true

--------------------
-- #region Server
--------------------

function PrestigeManager:server_onCreate()
    g_prestigeManager = g_prestigeManager or self

    self.sv = {}
    self.sv.saved = self.storage:load()
    if self.sv.saved == nil then
        self.sv.saved = {
            prestigePoints = 0,
            lastPrestigeGain = 0,
            specialItems = {}
        }
    else
        self.sv.saved = unpackNetworkData(self.sv.saved)
    end
end

function PrestigeManager:server_onFixedUpdate()
    local tick = sm.game.getCurrentTick()

    if tick % 40 == 0 then
        self:sv_saveData()
    end

    if self.sv.doPrestige and self.sv.doPrestige < tick then
        self.sv.doPrestige = nil
        if g_prestigeManager.getPrestigeGain() > 0 then
            self.sv.doSpawnCrate = tick + 40 * 3
        end
        self:sv_doPrestige()
    end

    if self.sv.doSpawnCrate and self.sv.doSpawnCrate < tick then
        self.sv.doSpawnCrate = nil
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
        prestigePoints = self.sv.saved.prestigePoints,
        lastPrestigeGain = self.sv.saved.lastPrestigeGain
    }
    self.network:setClientData(packNetworkData(clientData))
end

function PrestigeManager.sv_addPrestige(prestigePoints)
    g_prestigeManager.sv.saved.prestigePoints = g_prestigeManager.sv.saved.prestigePoints + prestigePoints
end

function PrestigeManager.sv_setPrestige(prestigePoints)
    g_prestigeManager.sv.saved.prestigePoints = prestigePoints
end

---@param prestigePoints number amount of prestige points to be used
---@return boolean success whether the amount of prestige points could be spent
function PrestigeManager.sv_trySpendPrestige(prestigePoints)
    if g_prestigeManager.sv.saved.prestigePoints - prestigePoints > 0 then
        g_prestigeManager.sv.saved.prestigePoints = g_prestigeManager.sv.saved.prestigePoints - prestigePoints
        sm.event.sendToScriptableObject(g_prestigeManager.scriptableObject, "sv_saveData")
        return true
    end
    return false
end

---add a special item so it won't be lost after a prestige
---@param uuid Uuid Uuid of the item to be kept
function PrestigeManager.sv_addSpecialItem(uuid)
    local quantity = g_prestigeManager.sv.saved.specialItems[tostring(uuid)] or 0
    g_prestigeManager.sv.saved.specialItems[tostring(uuid)] = math.min(quantity + 1, 65535)
    sm.event.sendToScriptableObject(g_prestigeManager.scriptableObject, "sv_saveData")
end

function PrestigeManager.sv_getSpecialItems()
    return (g_prestigeManager and g_prestigeManager.sv.saved.specialItems) or {}
end

function PrestigeManager.sv_startPrestige()
    sm.event.sendToPlayer(sm.player.getAllPlayers()[1], "sv_e_fadeToBlack", { duration = 1, timeout = 5 })
    sm.event.sendToPlayer(sm.player.getAllPlayers()[1], "sv_e_playEffect", { effect = "Prestige" })

    g_prestigeManager.sv.doPrestige = sm.game.getCurrentTick() + 40
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

-- #endregion

--------------------
-- #region Client
--------------------

function PrestigeManager:client_onCreate()
    g_prestigeManager = g_prestigeManager or self

    self.cl = {
        data = {
            prestigePoints = 0,
            lastPrestigeGain = 0
        }
    }
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

function PrestigeManager.cl_e_getLastPrestigeGain()
    return g_prestigeManager.cl.data.lastPrestigeGain
end

function PrestigeManager.cl_getPrestige()
    return (g_prestigeManager.sv and g_prestigeManager.sv.saved.prestigePoints) or
    g_prestigeManager.cl.data.prestigePoints
end

-- #endregion

---Returns how much prestige can be gained after doing a prestige rn based on current money.
---@return number prestige prestige points to be gained
function PrestigeManager.getPrestigeGain()
    local money = MoneyManager.getMoney()
    local minMoney = 1e9
    money = money - minMoney

    if money > 0 then
        return 2 ^ math.log(money, 10) / 100
    end
    return 0
end

--------------------
-- #region Types
--------------------

---@class PrestigeManagerSv
---@field saved PrestigeManagerSvSaved
---@field doPrestige integer|nil tick at which the next prestige should be done
---@field doSpawnCrate integer|nil tick at which the next prestige crate should be spawned

---@class PrestigeManagerSvSaved
---@field prestigePoints number available prestige points
---@field lastPrestigeGain number prestige points gained via the last prestige
---@field specialItems table<string, integer> table of items to be kept after a prestige <uuid, amount>

---@class PrestigeManagerCl
---@field data PrestigeManagerClData

---@class PrestigeManagerClData
---@field prestigePoints number available prestige points
---@field lastPrestigeGain number prestige points gained via the last prestige

-- #endregion
